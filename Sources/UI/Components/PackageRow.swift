import SwiftUI

struct PackageRow: View {
    let package: Package
    var showChevron: Bool = true
    var action: PackageAction? = nil
    var onAction: ((PackageAction) -> Void)? = nil
    
    var body: some View {
        NavigationLink(destination: PackageDetailView(package: package)) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: "shippingbox.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                // Package Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(package.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    HStack(spacing: 12) {
                        Text(package.version)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let section = package.section {
                            Text(section)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }
                    
                    if let description = package.description.prefix(60), !description.isEmpty {
                        Text(description + (package.description.count > 60 ? "..." : ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Action Button or Chevron
                if let action = action, onAction != nil {
                    PackageActionButton(
                        action: action,
                        package: package,
                        size: .small,
                        style: .bordered,
                        onAction: onAction
                    )
                } else if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Previews

struct PackageRow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            List {
                PackageRow(package: Package.samplePackages[0])
                PackageRow(
                    package: Package.samplePackages[1],
                    action: .install,
                    onAction: { _ in }
                )
            }
            .previewDisplayName("List View")
            
            VStack(spacing: 0) {
                PackageRow(package: Package.samplePackages[0])
                Divider()
                PackageRow(
                    package: Package.samplePackages[1],
                    action: .install,
                    onAction: { _ in }
                )
            }
            .padding()
            .previewDisplayName("Standalone")
        }
    }
}
