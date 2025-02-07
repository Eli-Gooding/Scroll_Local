import SwiftUI

struct VideoMetadataForm: View {
    @Environment(\.dismiss) var dismiss
    let onComplete: (String, String, String, Int) -> Void
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var category: String = "Attractions"
    
    private let categories = [
        "Attractions",
        "Eats",
        "Shopping",
        "Local Tips",
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Video Details")) {
                    TextField("Title", text: $title)
                    TextEditor(text: $description)
                        .frame(height: 100)
                        .overlay(
                            Group {
                                if description.isEmpty {
                                    Text("Description")
                                        .foregroundColor(.gray)
                                        .padding(.leading, 4)
                                        .padding(.top, 8)
                                }
                            },
                            alignment: .topLeading
                        )
                }
                
                Section(header: Text("Category")) {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                }
            }
            .navigationTitle("Video Details")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Upload") {
                    onComplete(title, description, category, 0) // Initialize with 0 comments
                    dismiss()
                }
                .disabled(title.isEmpty)
            )
        }
    }
}
