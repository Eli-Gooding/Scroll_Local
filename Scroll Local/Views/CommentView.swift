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
    
    // Common emojis for quick reactions
    private let quickEmojis = ["👍", "❤️", "😂", "😮", "👏", "🔥"]
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(viewModel.comments) { comment in
                            CommentCell(comment: comment) { emoji in
                                Task {
                                    try? await viewModel.addReaction(to: comment.id, emoji: emoji)
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
                    Task {
                        try? await viewModel.addComment(videoId: videoId, text: newCommentText)
                        newCommentText = ""
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
    
    private func groupedReactions() -> [(emoji: String, count: Int)] {
        let reactions = comment.reactions ?? []
        let grouped = Dictionary(grouping: reactions) { $0.emoji }
        return grouped.map { (emoji: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }
    
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
            
            // Reactions
            if !groupedReactions().isEmpty {
                HStack {
                    ForEach(groupedReactions(), id: \.emoji) { reaction in
                        Button(action: {
                            onEmojiSelected(reaction.emoji)
                        }) {
                            HStack {
                                Text(reaction.emoji)
                                Text("\(reaction.count)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                }
            }
            
            // Quick reaction buttons
            HStack {
                ForEach(["👍", "❤️", "😂"], id: \.self) { emoji in
                    Button(action: {
                        onEmojiSelected(emoji)
                    }) {
                        Text(emoji)
                            .font(.title3)
                    }
                    .padding(.trailing, 4)
                }
                
                Button(action: {
                    showingEmojiPicker.toggle()
                }) {
                    Image(systemName: "face.smiling")
                        .foregroundColor(.gray)
                }
                .popover(isPresented: $showingEmojiPicker) {
                    EmojiPickerView { emoji in
                        onEmojiSelected(emoji)
                        showingEmojiPicker = false
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct EmojiPickerView: View {
    let onEmojiSelected: (String) -> Void
    
    // Common emojis grouped by category
    private let emojis = [
        "Smileys": ["😀", "😃", "😄", "😁", "😅", "😂", "🤣", "😊", "😇"],
        "Gestures": ["👍", "👎", "👏", "🙌", "🤝", "👊", "✌️", "🤞", "🤟"],
        "Hearts": ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎"],
        "Other": ["🔥", "💯", "💪", "🎉", "✨", "💫", "💥", "💢", "💦"]
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 40))
            ], spacing: 10) {
                ForEach(Array(emojis.keys.sorted()), id: \.self) { category in
                    Section(header: Text(category)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top)) {
                        ForEach(emojis[category] ?? [], id: \.self) { emoji in
                            Button(action: {
                                onEmojiSelected(emoji)
                            }) {
                                Text(emoji)
                                    .font(.title2)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .frame(width: 300, height: 400)
    }
}
