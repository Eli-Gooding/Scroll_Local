import SwiftUI

struct ProfileView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
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
                        Text("Your Name")
                            .font(.headline)
                        Text("Your bio goes here • Add a brief description about yourself")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    // Edit Profile Button
                    Button(action: {
                        // Handle edit profile
                    }) {
                        Text("Edit Profile")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    // Content Tabs
                    VStack {
                        // Tab Selection
                        HStack {
                            TabButton(
                                isSelected: selectedTab == 0,
                                icon: "square.grid.3x3",
                                title: "Posts"
                            ) {
                                selectedTab = 0
                            }
                            
                            TabButton(
                                isSelected: selectedTab == 1,
                                icon: "bookmark",
                                title: "Saved"
                            ) {
                                selectedTab = 1
                            }
                        }
                        .padding(.vertical, 8)
                        
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
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        // Handle settings
                    }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }
}

struct StatView: View {
    let value: String
    let title: String
    
    var body: some View {
        VStack {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct TabButton: View {
    let isSelected: Bool
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(isSelected ? .primary : .secondary)
        }
        .overlay(alignment: .bottom) {
            if isSelected {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.primary)
            }
        }
    }
}

#Preview {
    ProfileView()
} 