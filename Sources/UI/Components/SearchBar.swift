import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search"
    var onCommit: (() -> Void)? = nil
    
    @State private var isEditing = false
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField(placeholder, text: $text, onCommit: {
                    withAnimation {
                        isEditing = false
                        onCommit?()
                    }
                })
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .foregroundColor(.primary)
                
                if !text.isEmpty {
                    Button(action: {
                        withAnimation {
                            self.text = ""
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .onTapGesture {
                withAnimation {
                    self.isEditing = true
                }
            }
            
            if isEditing {
                Button(action: {
                    withAnimation {
                        self.isEditing = false
                        self.text = ""
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }) {
                    Text("Cancel")
                        .foregroundColor(.accentColor)
                }
                .transition(.move(edge: .trailing))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

// MARK: - Previews

struct SearchBar_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: 20) {
                SearchBar(text: .constant(""))
                SearchBar(text: .constant("Sample search"))
            }
            .previewDisplayName("Light Mode")
            
            VStack(spacing: 20) {
                SearchBar(text: .constant(""))
                SearchBar(text: .constant("Sample search"))
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
        .previewLayout(.sizeThatFits)
    }
}
