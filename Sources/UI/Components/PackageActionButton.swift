import SwiftUI

struct PackageActionButton: View {
    let action: PackageAction
    let package: Package
    var size: ButtonSize = .medium
    var style: ButtonStyle = .bordered
    var isEnabled: Bool = true
    
    var onAction: ((PackageAction) -> Void)? = nil
    
    enum ButtonSize {
        case small, medium, large
        
        var padding: CGFloat {
            switch self {
            case .small: return 4
            case .medium: return 8
            case .large: return 12
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .small: return 4
            case .medium: return 8
            case .large: return 12
            }
        }
        
        var minWidth: CGFloat? {
            switch self {
            case .small: return nil
            case .medium: return 80
            case .large: return 120
            }
        }
    }
    
    enum ButtonStyle {
        case bordered, filled, text
    }
    
    var body: some View {
        Button(action: { onAction?(action) }) {
            HStack(spacing: 6) {
                Image(systemName: action.systemImage)
                
                if size != .small {
                    Text(action.rawValue)
                }
            }
            .frame(minWidth: size.minWidth)
            .padding(.vertical, size.padding)
            .padding(.horizontal, size.padding * 1.5)
            .foregroundColor(style == .filled ? .white : .accentColor)
            .background(
                style == .filled ? 
                    Color.accentColor : 
                    (style == .bordered ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .cornerRadius(size.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .stroke(style == .bordered ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}

// MARK: - Preview

struct PackageActionButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                PackageActionButton(
                    action: .install,
                    package: .samplePackages[0],
                    size: .small,
                    style: .filled
                )
                
                PackageActionButton(
                    action: .remove,
                    package: .samplePackages[0],
                    size: .small,
                    style: .bordered
                )
                
                PackageActionButton(
                    action: .upgrade,
                    package: .samplePackages[0],
                    size: .small,
                    style: .text
                )
            }
            
            HStack(spacing: 20) {
                PackageActionButton(
                    action: .install,
                    package: .samplePackages[0],
                    size: .medium,
                    style: .filled
                )
                
                PackageActionButton(
                    action: .remove,
                    package: .samplePackages[0],
                    size: .medium,
                    style: .bordered
                )
                
                PackageActionButton(
                    action: .upgrade,
                    package: .samplePackages[0],
                    size: .medium,
                    style: .text
                )
            }
            
            VStack(spacing: 10) {
                PackageActionButton(
                    action: .install,
                    package: .samplePackages[0],
                    size: .large,
                    style: .filled
                )
                
                PackageActionButton(
                    action: .remove,
                    package: .samplePackages[0],
                    size: .large,
                    style: .bordered
                )
                
                PackageActionButton(
                    action: .upgrade,
                    package: .samplePackages[0],
                    size: .large,
                    style: .text
                )
            }
            .frame(maxWidth: .infinity)
            
            PackageActionButton(
                action: .install,
                package: .samplePackages[0],
                size: .large,
                style: .filled,
                isEnabled: false
            )
            
            PackageActionButton(
                action: .remove,
                package: .samplePackages[0],
                size: .large,
                style: .bordered,
                isEnabled: false
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
