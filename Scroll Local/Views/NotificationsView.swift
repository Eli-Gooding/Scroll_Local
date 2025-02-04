import SwiftUI

struct NotificationsView: View {
    var body: some View {
        List {
            ForEach(0..<10) { _ in
                NotificationRow()
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NotificationRow: View {
    var body: some View {
        HStack(spacing: 12) {
            // Profile Image
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(.gray)
            
            // Notification Content
            VStack(alignment: .leading, spacing: 4) {
                Text("LocalExplorer")
                    .font(.headline) +
                Text(" liked your post")
                    .font(.subheadline)
                
                Text("2h ago")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Optional: Preview Image
            Image(systemName: "video.fill")
                .foregroundColor(.gray)
                .frame(width: 40, height: 40)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
} 