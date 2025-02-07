import SwiftUI

struct OtherUserProfileView: View {
    let userId: String
    @StateObject private var viewModel = OtherUserProfileViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedVideo: Video?
    @State private var showingFollowers = false
    @State private var showingFollowing = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Header
                HStack(spacing: 28) {
                    // Profile Image
                    if let profileImageUrl = viewModel.user?.profileImageUrl,
                       let url = URL(string: profileImageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 86, height: 86)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 86, height: 86)
                            .clipShape(Circle())
                            .foregroundColor(.gray)
                    }
                    
                    // Stats
                    HStack(spacing: 28) {
                        StatView(value: "\(viewModel.userPosts.count)", title: "Posts")
                        Button(action: { showingFollowers = true }) {
                            StatView(value: "\(viewModel.followerCount)", title: "Followers")
                        }
                        Button(action: { showingFollowing = true }) {
                            StatView(value: "\(viewModel.followingCount)", title: "Following")
                        }
                    }
                }
                .padding(.horizontal)
                
                // Bio Section
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.user?.displayName ?? "No Name")
                        .font(.headline)
                    if let bio = viewModel.user?.bio {
                        Text(bio)
                            .font(.subheadline)
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Follow Button
                Button(action: {
                    Task {
                        if viewModel.isFollowing {
                            try? await viewModel.unfollowUser()
                        } else {
                            try? await viewModel.followUser()
                        }
                    }
                }) {
                    Text(viewModel.isFollowing ? "Unfollow" : "Follow")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(viewModel.isFollowing ? Color(.systemGray6) : Color.accentColor)
                        .foregroundColor(viewModel.isFollowing ? .primary : .white)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                // Content Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 2) {
                    ForEach(viewModel.userPosts) { video in
                        VideoThumbnailView(video: video)
                            .onTapGesture {
                                selectedVideo = video
                            }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingFollowers) {
            FollowListView(userId: userId, listType: .followers)
        }
        .sheet(isPresented: $showingFollowing) {
            FollowListView(userId: userId, listType: .following)
        }
        .fullScreenCover(item: $selectedVideo) { video in
            VideoDetailView(video: video)
        }
        .task {
            await viewModel.loadUserProfile(userId: userId)
            await viewModel.fetchUserPosts(userId: userId)
        }
    }
}

#Preview {
    NavigationStack {
        OtherUserProfileView(userId: "LocalExplorer")
    }
} 