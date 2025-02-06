import SwiftUI

struct EmojiCategory: Identifiable {
    let id: String
    let name: String
    let emojis: [String]
}

struct EmojiPickerView: View {
    let onEmojiSelected: (String) -> Void
    
    // Popular/Frequently used emojis
    private let popularEmojis = ["👍", "❤️", "🎉", "🚀", "👏"]
    
    // Categorized emojis
    private let categories: [EmojiCategory] = [
        EmojiCategory(id: "faces", name: "Smileys & People", emojis: ["😊", "😂", "🥰", "😎", "🤔", "😅", "🙌", "👋", "🤝"]),
        EmojiCategory(id: "nature", name: "Nature", emojis: ["🌟", "🔥", "💫", "⭐️", "🌈", "🌸", "🌺", "🍀"]),
        EmojiCategory(id: "objects", name: "Objects", emojis: ["💡", "💪", "👑", "💎", "🎯", "🎨", "📱", "💻"]),
        EmojiCategory(id: "symbols", name: "Symbols", emojis: ["❤️", "💯", "✨", "💫", "⚡️", "💥", "🔥", "✅"])
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Popular section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Popular")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        ForEach(popularEmojis, id: \.self) { emoji in
                            Button(action: {
                                Task { @MainActor in
                                    onEmojiSelected(emoji)
                                }
                            }) {
                                Text(emoji)
                                    .font(.title2)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Divider()
                
                // Categories
                ForEach(categories) { category in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(category.name)
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 40, maximum: 40), spacing: 8)
                        ], spacing: 8) {
                            ForEach(category.emojis, id: \.self) { emoji in
                                Button(action: {
                                    Task { @MainActor in
                                        onEmojiSelected(emoji)
                                    }
                                }) {
                                    Text(emoji)
                                        .font(.title2)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    if category.id != categories.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemBackground))
    }
}
