import SwiftUI

struct CategoryToggleButton: View {
    let category: VideoCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(category.rawValue)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? category.color : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

#Preview {
    HStack {
        CategoryToggleButton(category: .attractions, isSelected: true) {}
        CategoryToggleButton(category: .eats, isSelected: false) {}
    }
    .padding()
} 