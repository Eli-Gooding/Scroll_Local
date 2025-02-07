import SwiftUI

struct ProfileView: View {
    @State private var selectedTab = 0
    @StateObject private var firebaseService = FirebaseService.shared
    @ObservedObject private var userService = UserService.shared
    @StateObject private var viewModel = ProfileViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditProfile = false
    @State private var selectedVideo: Video?
    @State private var showingFollowers = false
    @State private var showingFollowing = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header
                    HStack(spacing: 28) {
                        // Profile Image
                        if let profileImageUrl = userService.currentUser?.profileImageUrl,
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
                        Text(userService.currentUser?.displayName ?? "No Name")
                            .font(.headline)
                        Text(userService.currentUser?.email ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if let bio = userService.currentUser?.bio {
                            Text(bio)
                                .font(.subheadline)
                                .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    // Edit Profile Button
                    Button(action: {
                        showingEditProfile = true
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
                                Task {
                                    await viewModel.fetchUserPosts()
                                }
                            }
                            
                            TabButton(
                                isSelected: selectedTab == 1,
                                icon: "bookmark",
                                title: "Saved"
                            ) {
                                selectedTab = 1
                                Task {
                                    await viewModel.fetchSavedVideos()
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        
                        if viewModel.isLoading {
                            ProgressView()
                                .padding()
                        } else if let error = viewModel.error {
                            Text(error.localizedDescription)
                                .foregroundColor(.red)
                                .padding()
                        } else {
                            // Content Grid
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 2) {
                                let videos = selectedTab == 0 ? viewModel.userPosts : viewModel.savedVideos
                                ForEach(videos) { video in
                                    VideoThumbnailView(video: video)
                                        .onTapGesture {
                                            selectedVideo = video
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive, action: {
                            do {
                                try firebaseService.signOut()
                            } catch {
                                print("Error signing out: \(error)")
                            }
                        }) {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
            }
            .sheet(isPresented: $showingFollowers) {
                FollowListView(userId: userService.currentUser?.id ?? "", listType: .followers)
            }
            .sheet(isPresented: $showingFollowing) {
                FollowListView(userId: userService.currentUser?.id ?? "", listType: .following)
            }
            .fullScreenCover(item: $selectedVideo) { video in
                VideoDetailView(video: video)
            }
            .task {
                await viewModel.fetchUserPosts()
            }
        }
    }
}

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseService = FirebaseService.shared
    @ObservedObject private var userService = UserService.shared
    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    // Profile Image
                    HStack {
                        Spacer()
                        VStack {
                            if let selectedImage = selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else if let profileImageUrl = userService.currentUser?.profileImageUrl,
                                      let url = URL(string: profileImageUrl) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .foregroundColor(.gray)
                            }
                            
                            Button("Change Photo") {
                                showImagePicker = true
                            }
                            .font(.footnote)
                            .padding(.top, 4)
                        }
                        Spacer()
                    }
                    .padding(.vertical)
                }
                
                Section(header: Text("Profile Information")) {
                    TextField("Display Name", text: $displayName)
                    TextField("Bio", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Task {
                            // Upload image if selected
                            if let image = selectedImage {
                                do {
                                    _ = try await firebaseService.uploadProfileImage(image)
                                } catch {
                                    print("Error uploading profile image: \(error)")
                                }
                            }
                            
                            // Update profile information
                            do {
                                try await firebaseService.updateProfile(
                                    displayName: displayName,
                                    bio: bio
                                )
                                dismiss()
                            } catch {
                                print("Error updating profile: \(error)")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .onAppear {
                displayName = userService.currentUser?.displayName ?? ""
                bio = userService.currentUser?.bio ?? ""
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
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