import SwiftUI

struct CommentView: View {
    let videoId: String
    @StateObject private var viewModel = CommentViewModel()
    
    init(videoId: String) {
        self.videoId = videoId
    }
    
    @State private var newCommentText = ""
    @State private var showingEmojiPicker = false
    @State private var selectedCommentId: String?
    
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(viewModel.comments) { comment in
                            CommentCell(comment: comment) { emoji in
                                Task { @MainActor in
                                    do {
                                        try await viewModel.addReaction(to: comment.id, emoji: emoji)
                                    } catch {
                                        // Handle error if needed
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            
            // Comment input
            HStack {
                TextField("Add a comment...", text: $newCommentText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Button(action: {
                    let text = newCommentText // Capture the text
                    Task { @MainActor in
                        do {
                            try await viewModel.addComment(videoId: videoId, text: text)
                            newCommentText = ""
                        } catch {
                            // Handle error if needed
                        }
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                }
                .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.trailing)
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .shadow(radius: 2)
        }
        .onAppear {
            viewModel.loadComments(for: videoId)
        }
    }
}

#if DEBUG
struct CommentView_Previews: PreviewProvider {
    static var previews: some View {
        CommentView(videoId: "preview_video")
            .withPreviewFirebase(isAuthenticated: true)
    }
}
#endif

struct CommentCell: View {
    let comment: Comment
    let onEmojiSelected: (String) -> Void
    
    @State private var showingEmojiPicker = false
    
    // Common emojis for quick reactions
    private let quickEmojis = ["👍", "❤️", "🎉", "🚀", "👏"]
    

    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // User info
            HStack {
                Text(comment.user?.displayName ?? "Unknown User")
                    .font(.headline)
                Spacer()
                Text(comment.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Comment text
            Text(comment.text)
                .font(.body)
            
            // Grouped reactions in Slack style
            HStack(spacing: 4) {
                if !comment.groupedReactions.isEmpty {
                    ForEach(comment.groupedReactions, id: \.emoji) { reaction in
                        Button(action: {
                            onEmojiSelected(reaction.emoji)
                        }) {
                            HStack(spacing: 4) {
                                Text(reaction.emoji)
                                Text(String(reaction.count))
                                    .font(.caption)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                }
                
                // Add reaction button
                Button(action: { showingEmojiPicker.toggle() }) {
                    Image(systemName: "face.smiling")
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .popover(isPresented: $showingEmojiPicker) {
                    EmojiPickerView(onEmojiSelected: { emoji in
                        onEmojiSelected(emoji)
                        showingEmojiPicker = false
                    })
                    .frame(width: 300, height: 400)
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}


