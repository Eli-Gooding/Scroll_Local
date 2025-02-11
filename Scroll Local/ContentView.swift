//
//  ContentView.swift
//  Scroll Local
//
//  Created by Eli Gooding on 2/3/25.
//

import SwiftUI
import Firebase

struct ContentView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    
    var body: some View {
        Group {
            if firebaseService.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}

struct MainTabView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    
    var body: some View {
        NavigationStack {
            TabView {
                FeedView()
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                
                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                
                CaptureView()
                    .tabItem {
                        Label("Capture", systemImage: "plus.circle.fill")
                    }
                    .toolbarBackground(.black.opacity(0.01), for: .tabBar)
                    .toolbarColorScheme(.light, for: .tabBar)
                
                ExploreView()
                    .tabItem {
                        Label("Map", systemImage: "map")
                    }
                
                MessagesView()
                    .tabItem {
                        Label("Messages", systemImage: "message")
                    }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image("Scroll_Local_Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Text("Scroll Local")
                            .font(.headline)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        ProfileView()
                            .navigationBarBackButtonHidden(false)
                    } label: {
                        Image(systemName: "person.circle")
                            .font(.title2)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        NotificationsView()
                            .navigationBarBackButtonHidden(false)
                    } label: {
                        Image(systemName: "bell")
                            .font(.title2)
                    }
                }
            }
            .tint(.accentColor)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbar(.visible, for: .tabBar)
        }
    }
}

// TODO: This FeedView implementation has been moved to Views/FeedView.swift
// Keeping this commented out for reference
/*
// Feed View
struct FeedView: View {
    @State private var selectedFeed = 0
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Feed Type", selection: $selectedFeed) {
                    Text("Following").tag(0)
                    Text("Local Area").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if selectedFeed == 0 {
                    FollowingFeedView()
                } else {
                    LocalAreaFeedView()
                }
            }
            .navigationTitle("Scroll Local")
        }
    }
}

// Placeholder Views
struct FollowingFeedView: View {
    var body: some View {
        Text("Following Feed")
    }
}

struct LocalAreaFeedView: View {
    var body: some View {
        Text("Local Area Feed")
    }
}
*/

struct SavedVideosView: View {
    var body: some View {
        Text("Saved Videos Coming Soon")
    }
}

#Preview {
    ContentView()
}
