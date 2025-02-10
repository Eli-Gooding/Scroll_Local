import SwiftUI

struct MessagesView: View {
    @StateObject private var viewModel = MessagesViewModel()
    @State private var showingNewMessage = false
    @State private var selectedConversationId: String?
    @State private var selectedOtherUserId: String?
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            List {
                ForEach(viewModel.conversations) { conversation in
                    NavigationLink(destination: ChatView(conversationId: conversation.id, otherUserId: conversation.otherUserId)) {
                        MessageRow(conversation: conversation)
                    }
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingNewMessage) {
                NewMessageView { userId in
                    Task {
                        let conversationId = await viewModel.createOrGetConversation(with: userId)
                        showingNewMessage = false
                        selectedConversationId = conversationId
                        selectedOtherUserId = userId
                    }
                }
            }
            .background(
                NavigationLink(
                    destination: Group {
                        if let conversationId = selectedConversationId,
                           let otherUserId = selectedOtherUserId {
                            ChatView(conversationId: conversationId, otherUserId: otherUserId)
                        }
                    },
                    isActive: Binding(
                        get: { selectedConversationId != nil },
                        set: { if !$0 { selectedConversationId = nil; selectedOtherUserId = nil } }
                    )
                ) {
                    EmptyView()
                }
            )
            
            Button(action: {
                showingNewMessage = true
            }) {
                Image(systemName: "square.and.pencil")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
    }
}

struct MessageRow: View {
    let conversation: MessagesViewModel.Conversation
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Image
            if let profileUrl = conversation.otherUserProfileUrl {
                AsyncImage(url: URL(string: profileUrl)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.gray)
                    @unknown default:
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.gray)
            }
            
            // Message Content
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.otherUserName)
                    .font(.headline)
                
                Text(conversation.lastMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Timestamp and unread indicator
            VStack(alignment: .trailing, spacing: 4) {
                Text(timeAgo(from: conversation.lastMessageTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if conversation.unreadCount > 0 {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @State private var messageText = ""
    
    init(conversationId: String, otherUserId: String) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversationId: conversationId, otherUserId: otherUserId))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding()
            }
            
            // Message input
            HStack(spacing: 12) {
                TextField("Message", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Button(action: {
                    if !messageText.isEmpty {
                        viewModel.sendMessage(messageText)
                        messageText = ""
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .shadow(radius: 1)
        }
        .navigationTitle(viewModel.otherUser?.displayName ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MessageBubble: View {
    let message: ChatViewModel.Message
    
    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer()
            }
            
            Text(message.text)
                .padding(12)
                .background(message.isFromCurrentUser ? Color.accentColor : Color(.systemGray5))
                .foregroundColor(message.isFromCurrentUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            if !message.isFromCurrentUser {
                Spacer()
            }
        }
    }
}

struct NewMessageView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var searchResults: [MessagesViewModel.UserSearchResult] = []
    let onUserSelected: (String) -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(searchResults) { user in
                    Button(action: {
                        onUserSelected(user.id)
                    }) {
                        HStack {
                            if let profileUrl = user.profileImageUrl {
                                AsyncImage(url: URL(string: profileUrl)) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    case .failure:
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .foregroundColor(.gray)
                                    @unknown default:
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .foregroundColor(.gray)
                                    }
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.gray)
                            }
                            
                            Text(user.displayName)
                                .font(.body)
                        }
                    }
                }
            }
            .searchable(text: $searchText)
            .onChange(of: searchText) { newValue in
                // Debounce search
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if searchText == newValue {
                        searchResults = await MessagesViewModel().searchUsers(query: newValue)
                    }
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MessagesView()
    }
} 