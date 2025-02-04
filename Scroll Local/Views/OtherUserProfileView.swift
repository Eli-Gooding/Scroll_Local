import SwiftUI

struct OtherUserProfileView: View {
    let username: String
    @State private var selectedTab = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Header
                HStack(spacing: 28) {
                    // Profile Image
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 86, height: 86)
                        .clipShape(Circle())
                        .foregroundColor(.gray)
                    
                    // Stats
                    HStack(spacing: 28) {
                        StatView(value: "24", title: "Posts")
                        StatView(value: "128", title: "Followers")
                        StatView(value: "164", title: "Following")
                    }
                }
                .padding(.horizontal)
                
                // Bio Section
                VStack(alignment: .leading, spacing: 4) {
                    Text(username)
                        .font(.headline)
                    Text("Bio description • Local content creator")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Follow Button
                Button(action: {
                    // Handle follow/unfollow
                }) {
                    Text("Follow")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                // Content Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 2) {
                    ForEach(0..<15) { index in
                        Rectangle()
                            .aspectRatio(1, contentMode: .fill)
                            .foregroundColor(Color(.systemGray5))
                    }
                }
                .padding(.top)
            }
        }
        .navigationTitle(username)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        OtherUserProfileView(username: "LocalExplorer")
    }
} 