import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var selectedTab = 0
    @State private var selectedVideo: Video?
    @State private var showVideoDetail = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar and suggestions
                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search videos, places, or tags...", text: $viewModel.searchText)
                            .textFieldStyle(.plain)
                            .autocapitalization(.none)
                        if !viewModel.searchText.isEmpty {
                            Button(action: {
                                viewModel.searchText = ""
                                Task {
                                    await viewModel.updateSuggestions()
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        if !viewModel.searchText.isEmpty {
                            Button("Search") {
                                Task {
                                    await viewModel.performSearch()
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    
                    // Category filters
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(VideoCategory.allCases, id: \.self) { category in
                                CategoryToggleButton(
                                    category: category,
                                    isSelected: viewModel.selectedCategories.contains(category)
                                ) {
                                    viewModel.toggleCategory(category)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .background(Color(.systemBackground))
                    
                    // Search suggestions
                    if !viewModel.suggestions.isEmpty && !viewModel.searchText.isEmpty {
                        List(viewModel.suggestions) { suggestion in
                            Button(action: {
                                viewModel.searchText = suggestion.displayText.replacingOccurrences(of: "#", with: "")
                                Task {
                                    await viewModel.performSearch()
                                }
                            }) {
                                HStack {
                                    Image(systemName: suggestion.type == "Tag" ? "number" :
                                            suggestion.type == "Location" ? "mappin" : "magnifyingglass")
                                        .foregroundColor(.gray)
                                    VStack(alignment: .leading) {
                                        Text(suggestion.displayText)
                                        Text(suggestion.type)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                
                // Search results
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                } else if let error = viewModel.error {
                    Spacer()
                    Text("Error: \(error.localizedDescription)")
                        .foregroundColor(.red)
                    Spacer()
                } else if !viewModel.searchText.isEmpty {
                    // Results tabs
                    Picker("Results", selection: $selectedTab) {
                        Text("Videos (\(viewModel.searchResults.videos.count))").tag(0)
                        Text("Tags (\(viewModel.searchResults.tagResults.count))").tag(1)
                        Text("Places (\(viewModel.searchResults.placeResults.count))").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    // Results grid
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            switch selectedTab {
                            case 0:
                                ForEach(viewModel.searchResults.videos) { video in
                                    SearchVideoCard(video: video)
                                        .onTapGesture {
                                            selectedVideo = video
                                            showVideoDetail = true
                                        }
                                }
                            case 1:
                                ForEach(viewModel.searchResults.tagResults) { tagResult in
                                    ForEach(tagResult.videos) { video in
                                        SearchVideoCard(video: video)
                                            .onTapGesture {
                                                selectedVideo = video
                                                showVideoDetail = true
                                            }
                                    }
                                }
                            case 2:
                                ForEach(viewModel.searchResults.placeResults) { placeResult in
                                    ForEach(placeResult.videos) { video in
                                        SearchVideoCard(video: video)
                                            .onTapGesture {
                                                selectedVideo = video
                                                showVideoDetail = true
                                            }
                                    }
                                }
                            default:
                                EmptyView()
                            }
                        }
                        .padding()
                    }
                } else {
                    // Empty state
                    Spacer()
                    Text("Search for videos by title, location, or tags")
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
        }
        .onChange(of: viewModel.searchText) { _ in
            Task {
                await viewModel.updateSuggestions()
            }
        }
        .fullScreenCover(item: $selectedVideo) { video in
            VideoDetailView(video: video)
        }
    }
}

struct SearchVideoCard: View {
    let video: Video
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            if let thumbnailUrl = video.thumbnailUrl,
               let url = URL(string: thumbnailUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .aspectRatio(9/16, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(9/16, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Video info
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.headline)
                    .lineLimit(2)
                
                NavigationLink(destination: ExploreView(initialLocation: video.location)) {
                    Text(video.formattedLocation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label("\(video.views)", systemImage: "eye.fill")
                    Label("\(video.saveCount)", systemImage: "bookmark.fill")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

private struct CategoryToggleButton: View {
    let category: VideoCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(category.rawValue)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? category.color : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

#Preview {
    SearchView()
} 