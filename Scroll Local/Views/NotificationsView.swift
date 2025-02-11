import SwiftUI

struct NotificationsView: View {
    @StateObject private var viewModel = NotificationsViewModel()
    
    var body: some View {
        List {
            ForEach(viewModel.notifications) { notification in
                NotificationRow(notification: notification)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.deleteNotification(notification.id)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.startListening()
        }
        .onDisappear {
            viewModel.stopListening()
        }
    }
}

struct NotificationRow: View {
    let notification: NotificationsViewModel.Notification
    
    var body: some View {
        NavigationLink(destination: FeedView(initialVideoId: notification.videoId)) {
            HStack(spacing: 12) {
                // Profile Image
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.gray)
                
                // Notification Content
                VStack(alignment: .leading, spacing: 4) {
                    Group {
                        Text(notification.senderDisplayName)
                            .font(.headline) +
                        Text(notification.type == .save ? " saved your post" : " commented on your post")
                            .font(.subheadline)
                    }
                    
                    if let commentText = notification.commentText {
                        Text(commentText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Text(notification.createdAt.timeAgo())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Video thumbnail placeholder
                Image(systemName: "video.fill")
                    .foregroundColor(.gray)
                    .frame(width: 40, height: 40)
            }
            .padding(.vertical, 4)
        }
    }
}

extension Date {
    func timeAgo() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
} 