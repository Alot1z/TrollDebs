import SwiftUI

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.secondary)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VStack {
        DetailRow(icon: "number", label: "Identifier", value: "com.example.app")
        DetailRow(icon: "tag", label: "Version", value: "1.0.0")
        DetailRow(icon: "person", label: "Author", value: "John Doe <john@example.com>")
    }
    .padding()
}
