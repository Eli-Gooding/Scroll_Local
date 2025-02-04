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
    @Environment(\.isPreview) var isPreview
    
    var body: some View {
        Group {
            if isPreview {
                if PreviewFirebaseService.shared.isAuthenticated {
                    MainTabView()
                } else {
                    LoginView()
                }
            } else {
                if firebaseService.isAuthenticated {
                    MainTabView()
                } else {
                    LoginView()
                }
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
                
                ExploreView()
                    .tabItem {
                        Label("Map", systemImage: "map")
                    }
                
                MessagesView()
                    .tabItem {
                        Label("Messages", systemImage: "message")
                    }
            }
            .navigationTitle("Scroll Local")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
        }
        .onAppear {
            #if DEBUG
            firebaseService.debugPrintAuthState()
            #endif
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

struct SearchView: View {
    var body: some View {
        Text("Search Coming Soon")
    }
}

struct CaptureView: View {
    var body: some View {
        Text("Capture Coming Soon")
    }
}

struct ExploreView: View {
    var body: some View {
        Text("Map View Coming Soon")
    }
}

struct SavedVideosView: View {
    var body: some View {
        Text("Saved Videos Coming Soon")
    }
}

#Preview {
    ContentView()
        .withPreviewFirebase(isAuthenticated: true)
}
