//
//  ContentView.swift
//  Scroll Local
//
//  Created by Eli Gooding on 2/3/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
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
        NavigationView {
            Text("Search Coming Soon")
                .navigationTitle("Search")
        }
    }
}

struct CaptureView: View {
    var body: some View {
        NavigationView {
            Text("Capture Coming Soon")
                .navigationTitle("Capture")
        }
    }
}

struct ExploreView: View {
    var body: some View {
        NavigationView {
            Text("Map View Coming Soon")
                .navigationTitle("Map")
        }
    }
}

struct SavedVideosView: View {
    var body: some View {
        NavigationView {
            Text("Saved Videos Coming Soon")
                .navigationTitle("Saved")
        }
    }
}

struct MessagesView: View {
    var body: some View {
        NavigationView {
            Text("Messages Coming Soon")
                .navigationTitle("Messages")
        }
    }
}

struct ProfileView: View {
    var body: some View {
        NavigationView {
            Text("Profile Coming Soon")
                .navigationTitle("Profile")
        }
    }
}

#Preview {
    ContentView()
}
