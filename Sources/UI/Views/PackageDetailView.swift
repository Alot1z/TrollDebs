import SwiftUI

struct PackageDetailView: View {
    // MARK: - Properties
    
    @StateObject private var viewModel: PackageDetailViewModel
    @State private var showInjectionView = false
    @State private var showConfirmDialog = false
    @State private var pendingAction: Package.PackageAction?
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String? = nil
    @State private var showError = false
    @State private var showSuccess = false
    @State private var successMessage = ""
    
    // MARK: - Initialization
    
    init(package: Package) {
        _viewModel = StateObject(wrappedValue: PackageDetailViewModel(package: package))
    }
    
    // MARK: - Computed Properties
    
    private var package: Package {
        viewModel.package
    }
    
    private var availableActions: [Package.PackageAction] {
        var actions: [Package.PackageAction] = []
        
        // Always show details
        actions.append(.showDetails)
        
        if package.isInstalled {
            actions.append(.remove)
            actions.append(.reinstall)
            
            // Only show inject if the package is not already injected
            if !package.isInjected {
                actions.append(.inject)
            }
        } else {
            actions.append(.install)
        }
        
        return actions
    }
    
    // MARK: - Views
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with package icon and name
                headerView
                
                // Package description
                if !package.description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Text(package.description)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                }
                
                // Package details
                VStack(alignment: .leading, spacing: 8) {
                    Text("Package Details")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        DetailRow(icon: "number", label: "Identifier", value: package.identifier)
                        DetailRow(icon: "tag", label: "Version", value: package.version)
                        DetailRow(icon: "cpu", label: "Architecture", value: package.architecture)
                        
                        if let section = package.section {
                            DetailRow(icon: "folder", label: "Section", value: section)
                        }
                        
                        if let author = package.author, !author.isEmpty {
                            DetailRow(icon: "person", label: "Author", value: author)
                        }
                        
                        if let maintainer = package.maintainer, maintainer != package.author {
                            DetailRow(icon: "person.crop.square", label: "Maintainer", value: maintainer)
                        }
                        
                        DetailRow(icon: "internaldrive", label: "Installed Size", value: package.formattedSize)
                        
                        if let size = package.fileSize, size > 0 {
                            DetailRow(icon: "arrow.down.doc", label: "Download Size", value: package.formattedPackageSize)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                // Dependencies
                if let depends = package.depends, !depends.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dependencies")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(depends, id: \.self) { dependency in
                                Text("• \(dependency)")
                                    .font(.subheadline)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }
                
                // Action buttons
                actionButtons
                    .padding(.vertical)
            }
            .padding(.bottom)
        }
        .navigationBarTitle(package.displayName, displayMode: .inline)
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") {
                successMessage = ""
                if viewModel.shouldDismissView {
                    dismiss()
                }
            }
        } message: {
            Text(successMessage)
        }
        .confirmationDialog(
            "Confirm Action",
            isPresented: $showConfirmDialog,
            titleVisibility: .visible
        ) {
            if let action = pendingAction {
                Button(action.rawValue, role: .destructive) {
                    Task { await performAction(action) }
                }
            }
            Button("Cancel", role: .cancel) {
                pendingAction = nil
            }
        } message: {
            if let action = pendingAction {
                switch action {
                case .remove:
                    Text("Are you sure you want to remove this package?")
                case .reinstall:
                    Text("This will reinstall the package. Continue?")
                default:
                    Text("Are you sure you want to perform this action?")
                }
            }
        }
        .sheet(isPresented: $showInjectionView) {
            NavigationView {
                PackageInjectionView(package: package)
                    .navigationBarTitle("Inject into App", displayMode: .inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showInjectionView = false
                            }
                        }
                    }
            }
        }
    }
    
    // MARK: - Action Handling
    
    private func performAction(_ action: Package.PackageAction) async {
        do {
            switch action {
            case .install, .upgrade, .reinstall:
                try await viewModel.installPackage()
                successMessage = "Package successfully installed"
                showSuccess = true
                
            case .remove:
                try await viewModel.removePackage()
                successMessage = "Package successfully removed"
                showSuccess = true
                
            case .inject:
                showInjectionView = true
                
            case .showDetails:
                // No action needed, details are already shown
                break
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background circle with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                package.isInjected ? Color.orange.opacity(0.1) : Color.accentColor.opacity(0.1),
                                package.isInjected ? Color.orange.opacity(0.2) : Color.accentColor.opacity(0.2)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: package.isInjected ? Color.orange.opacity(0.2) : Color.accentColor.opacity(0.2), radius: 10, x: 0, y: 5)
                
                // Package or injection icon with animation
                Group {
                    if package.isInjected {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                    } else {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.accentColor)
                    }
                }
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.bounce, value: package.isInjected)
            }
            .padding(.top, 20)
            
            VStack(spacing: 4) {
                Text(package.displayName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(package.version)
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                if let section = package.section {
                    Text(section.uppercased())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.accentColor)
                        .cornerRadius(4)
                }
            }
            
            Text(package.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 8)
            
            actionButtons
        }
        .padding(.bottom, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Main action buttons
            ForEach(availableActions, id: \.self) { action in
                if action == .inject {
                    // Special handling for inject button to show the injection view
                    Button(action: {
                        showInjectionView = true
                    }) {
                        HStack {
                            Image(systemName: action.systemImage)
                                .frame(width: 24)
                            Text(action.rawValue)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(viewModel.isInstalling || viewModel.isRemoving)
                } else {
                    // Standard action button
                    Button(action: {
                        if action.isDestructive {
                            pendingAction = action
                            showConfirmDialog = true
                        } else {
                            Task { await performAction(action) }
                        }
                    }) {
                        HStack {
                            Image(systemName: action.systemImage)
                                .frame(width: 24)
                            Text(action.rawValue)
                            Spacer()
                            
                            if (action == .install || action == .upgrade || action == .reinstall) && viewModel.isInstalling {
                                ProgressView()
                                    .padding(.trailing, 8)
                            } else if action == .remove && viewModel.isRemoving {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(action.isDestructive ? Color.red : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(viewModel.isInstalling || viewModel.isRemoving)
                }
            }
            
            // Show injection status if injected
            if package.isInjected, let appName = package.injectedIntoApp, let date = package.injectionDate {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Injected into")
                        Text(appName)
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    
                    Text("Injected \(date.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    NavigationLink(destination: InjectedPackageDetailView(package: package)) {
                        HStack {
                            Image(systemName: "cube.transparent")
                            Text("Manage Injection")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Preview

struct PackageDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PackageDetailView(package: .mock())
        }
    }
}
