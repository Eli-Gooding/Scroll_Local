import SwiftUI

struct MessagesView: View {
    var body: some View {
        List {
            ForEach(0..<10) { _ in
                MessageRow()
            }
        }
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Handle new message
                }) {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
    }
}

struct MessageRow: View {
    var body: some View {
        HStack(spacing: 12) {
            // Profile Image
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 50, height: 50)
                .foregroundColor(.gray)
            
            // Message Content
            VStack(alignment: .leading, spacing: 4) {
                Text("LocalExplorer")
                    .font(.headline)
                
                Text("Check out this cool spot I found!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Timestamp
            VStack(alignment: .trailing, spacing: 4) {
                Text("2h")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        MessagesView()
    }
} 