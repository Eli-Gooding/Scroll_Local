import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

@MainActor
class CommentViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    private var isPreviewMode: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != nil
        #else
        return false
        #endif
    }
    
    func loadComments(for videoId: String) {
        isLoading = true
        
        if isPreviewMode {
            // Load preview data
            comments = [
                Comment(id: "1", videoId: videoId, userId: "preview_user", text: "This is a preview comment!", createdAt: Date(), likes: 5, isReply: false, parentCommentId: nil, replyCount: 0, user: User(id: "preview_user", email: "preview@example.com", displayName: "Preview User", createdAt: Date()), reactions: [
                    Reaction(id: "1", userId: "preview_user", emoji: "👍", createdAt: Date(), commentId: "1", user: User(id: "preview_user", email: "preview@example.com", displayName: "Preview User", createdAt: Date()))
                ]),
                Comment(id: "2", videoId: videoId, userId: "preview_user2", text: "Another preview comment with a reaction!", createdAt: Date().addingTimeInterval(-3600), likes: 3, isReply: false, parentCommentId: nil, replyCount: 0, user: User(id: "preview_user2", email: "preview2@example.com", displayName: "Preview User 2", createdAt: Date()), reactions: [
                    Reaction(id: "2", userId: "preview_user", emoji: "❤️", createdAt: Date(), commentId: "2", user: User(id: "preview_user", email: "preview@example.com", displayName: "Preview User", createdAt: Date()))
                ])
            ]
            isLoading = false
            return
        }
        
        // Listen for real-time updates to comments
        listenerRegistration = db.collection("comments")
            .whereField("videoId", isEqualTo: videoId)
            .whereField("isReply", isEqualTo: false)  // Only get top-level comments
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.error = error
                    self.isLoading = false
                    return
                }
                
                self.comments = querySnapshot?.documents.compactMap { document -> Comment? in
                    try? document.data(as: Comment.self)
                } ?? []
                
                // Load user data for each comment
                Task { @MainActor in
                    var updatedComments = self.comments
                    for index in updatedComments.indices {
                        if let user = try? await UserService.shared.fetchUser(withId: updatedComments[index].userId) {
                            updatedComments[index].user = user
                        }
                        
                        // Load reactions for each comment
                        let reactions = try? await self.loadReactions(for: updatedComments[index].id)
                        updatedComments[index].reactions = reactions
                    }
                    self.comments = updatedComments
                }
                
                self.isLoading = false
            }
    }
    
    func addComment(videoId: String, text: String) async throws {
        if isPreviewMode {
            let previewComment = Comment(
                id: UUID().uuidString,
                videoId: videoId,
                userId: "preview_user",
                text: text,
                createdAt: Date(),
                likes: 0,
                isReply: false,
                parentCommentId: nil,
                replyCount: 0,
                user: User(id: "preview_user", email: "preview@example.com", displayName: "Preview User", createdAt: Date()),
                reactions: []
            )
            comments.insert(previewComment, at: 0)
            return
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        let commentRef = db.collection("comments").document()
        
        let comment = Comment(
            id: commentRef.documentID,
            videoId: videoId,
            userId: userId,
            text: text,
            createdAt: Date(),
            likes: 0,
            isReply: false,
            parentCommentId: nil,
            replyCount: 0
        )
        
        try commentRef.setData(from: comment)
        
        // Update video's comment count
        let videoRef = db.collection("videos").document(videoId)
        try await videoRef.updateData([
            "comment_count": FieldValue.increment(Int64(1))
        ])
        
        // Add comment to local state immediately
        var updatedComment = comment
        if let currentUser = Auth.auth().currentUser {
            updatedComment.user = User(id: currentUser.uid, email: currentUser.email ?? "", displayName: currentUser.displayName ?? "User", createdAt: Date())
        }
        
        let updatedComments = await MainActor.run { () -> [Comment] in
            var currentComments = self.comments
            currentComments.insert(updatedComment, at: 0)
            return currentComments
        }
        
        await MainActor.run {
            self.comments = updatedComments
        }
    }
    
    func addReaction(to commentId: String, emoji: String) async throws {
        if isPreviewMode {
            let updatedComments = await MainActor.run { () -> [Comment] in
                var currentComments = self.comments
                if let index = currentComments.firstIndex(where: { $0.id == commentId }) {
                    let previewReaction = Reaction(
                        id: UUID().uuidString,
                        userId: "preview_user",
                        emoji: emoji,
                        createdAt: Date(),
                        commentId: commentId,
                        user: User(id: "preview_user", email: "preview@example.com", displayName: "Preview User", createdAt: Date())
                    )
                    
                    var updatedComment = currentComments[index]
                    if updatedComment.reactions == nil {
                        updatedComment.reactions = []
                    }
                    
                    // Remove existing reaction with same emoji if it exists
                    updatedComment.reactions?.removeAll(where: { $0.emoji == emoji && $0.userId == "preview_user" })
                    // Add new reaction if it wasn't removed (toggle behavior)
                    if updatedComment.reactions?.count == currentComments[index].reactions?.count {
                        updatedComment.reactions?.append(previewReaction)
                    }
                    
                    currentComments[index] = updatedComment
                }
                return currentComments
            }
            
            await MainActor.run {
                self.comments = updatedComments
            }
            return
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        // Check if user already reacted with this emoji
        let existingReaction = try await db.collection("reactions")
            .whereField("userId", isEqualTo: userId)
            .whereField("commentId", isEqualTo: commentId)
            .whereField("emoji", isEqualTo: emoji)
            .getDocuments()
        
        if existingReaction.documents.isEmpty {
            // Add new reaction
            let reactionRef = db.collection("reactions").document()
            
            let reaction = Reaction(
                id: reactionRef.documentID,
                userId: userId,
                emoji: emoji,
                createdAt: Date(),
                commentId: commentId
            )
            
            try reactionRef.setData(from: reaction)
            
            // Update local state immediately
            let updatedComments = await MainActor.run { () -> [Comment] in
                var currentComments = self.comments
                if let index = currentComments.firstIndex(where: { $0.id == commentId }) {
                    var updatedComment = currentComments[index]
                    var reactions = updatedComment.reactions ?? []
                    reactions.append(reaction)
                    updatedComment.reactions = reactions
                    currentComments[index] = updatedComment
                }
                return currentComments
            }
            await MainActor.run {
                self.comments = updatedComments
            }
        } else {
            // Remove existing reaction
            try await existingReaction.documents.first?.reference.delete()
            
            // Update local state immediately
            let updatedComments = await MainActor.run { () -> [Comment] in
                var currentComments = self.comments
                if let index = currentComments.firstIndex(where: { $0.id == commentId }) {
                    var updatedComment = currentComments[index]
                    updatedComment.reactions?.removeAll(where: { $0.emoji == emoji && $0.userId == userId })
                    currentComments[index] = updatedComment
                }
                return currentComments
            }
            await MainActor.run {
                self.comments = updatedComments
            }
        }
    }
    
    private func loadReactions(for commentId: String) async throws -> [Reaction] {
        let snapshot = try await db.collection("reactions")
            .whereField("commentId", isEqualTo: commentId)
            .getDocuments()
        
        var reactions = snapshot.documents.compactMap { document -> Reaction? in
            try? document.data(as: Reaction.self)
        }
        
        // Load user data for each reaction
        for index in reactions.indices {
            if let user = try? await UserService.shared.fetchUser(withId: reactions[index].userId) {
                reactions[index].user = user
            }
        }
        
        return reactions
    }
    
    deinit {
        listenerRegistration?.remove()
    }
}
