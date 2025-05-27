import SwiftUI
import Combine

struct PackageInjectionView: View {
    // MARK: - Properties
    
    @StateObject private var viewModel: PackageInjectionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = ""
    
    // MARK: - Initialization
    
    init(package: Package) {
        _viewModel = StateObject(wrappedValue: PackageInjectionViewModel(package: package))
    }
    
    // For previews
    fileprivate init(viewModel: PackageInjectionViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - Body
    
    var body: some View {
        List {
            // Search bar
            Section {
                TextField("Search Apps", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
            }
            
            // App list
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if filteredApps.isEmpty {
                Text("No apps found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(filteredApps) { app in
                    Button {
                        viewModel.selectApp(app)
                    } label: {
                        HStack {
                            // App icon
                            if let icon = app.icon {
                                Image(uiImage: icon)
                                    .resizable()
                                    .frame(width: 44, height: 44)
                                    .cornerRadius(8)
                            } else {
                                Image(systemName: "app")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 44, height: 44)
                                    .foregroundColor(.blue)
                            }
                            
                            // App name and bundle ID
                            VStack(alignment: .leading) {
                                Text(app.name)
                                    .font(.headline)
                                Text(app.bundleIdentifier)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Selection indicator
                            if viewModel.selectedApp?.id == app.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .navigationTitle("Select App")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Inject") {
                    Task {
                        do {
                            try await viewModel.injectPackage()
                            successMessage = "Successfully injected package into \(viewModel.selectedApp?.name ?? "app")"
                            showSuccess = true
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }
                .disabled(viewModel.selectedApp == nil || viewModel.isInjecting)
            }
        }
        .task {
            do {
                try await viewModel.loadInstalledApps()
            } catch {
                errorMessage = "Failed to load installed apps: \(error.localizedDescription)"
                showError = true
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                errorMessage = ""
            }
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") {
                successMessage = ""
                dismiss()
            }
        } message: {
            Text(successMessage)
        }
        .overlay {
            if viewModel.isLoading || viewModel.isInjecting {
                ProgressView(viewModel.isInjecting ? "Injecting..." : "Loading...")
                    .padding()
                    .background(Color(.systemBackground).opacity(0.9))
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        }
    }
    
    // MARK: - Private Views
    
    private func AppRow(app: PackageInjectionViewModel.InstalledApp, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                // App icon
                if let icon = app.icon {
                    Image(uiImage: icon)
                        .resizable()
                        .frame(width: 44, height: 44)
                        .cornerRadius(8)
                } else {
                    Image(systemName: "app")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                        .foregroundColor(.blue)
                }
                
                // App info
                VStack(alignment: .leading) {
                    Text(app.displayName)
                        .font(.headline)
                    
                    Text(app.bundleIdentifier)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let version = app.version {
                        Text("Version: \(version)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Computed Properties
    
    private var filteredApps: [PackageInjectionViewModel.InstalledApp] {
        if searchText.isEmpty {
            return viewModel.installedApps
        } else {
            return viewModel.installedApps.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - Views
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading apps...")
            } else if viewModel.installedApps.isEmpty {
                ContentUnavailableView(
                    "No Apps Found",
                    systemImage: "app.badge",
                    description: Text("No compatible apps were found on your device.")
                )
            } else {
                List {
                    Section {
                        ForEach(filteredApps) { app in
                            AppRow(app: app) {
                                viewModel.selectApp(app)
                            }
                            .listRowBackground(viewModel.selectedApp?.bundleIdentifier == app.bundleIdentifier ?
                                              Color.accentColor.opacity(0.1) : Color.clear)
                        }
                    } header: {
                        Text("Select an app to inject into")
                    } footer: {
                        if !searchText.isEmpty {
                            Text("\(filteredApps.count) \(filteredApps.count == 1 ? "app" : "apps") found")
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search apps")
            }
        }
        .navigationTitle("Inject into App")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isInjecting {
                    ProgressView()
                } else {
                    Button("Inject") {
                        Task { await viewModel.injectPackage() }
                    }
                    .disabled(viewModel.selectedApp == nil || viewModel.isInjecting)
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("Injection Complete", isPresented: $viewModel.showSuccess) {
            Button("Done") {
                dismiss()
            }
        } message: {
            if let appName = viewModel.selectedApp?.displayName {
                Text("Successfully injected \(viewModel.package.name) into \(appName)")
            }
        }
        .task {
            await viewModel.loadInstalledApps()
        }
    }
}

// MARK: - Subviews

private struct AppRow: View {
    let app: InstalledApp
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let icon = app.icon {
                    Image(uiImage: icon)
                        .resizable()
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)
                } else {
                    Image(systemName: "app")
                        .font(.system(size: 20))
                        .frame(width: 40, height: 40)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.displayName)
                        .font(.subheadline)
                        .lineLimit(1)
                    
                    Text(app.bundleIdentifier)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if let version = app.version {
                    Text(version)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        PackageInjectionView(package: Package.samplePackage())
    }
}

#Preview("Loading") {
    let viewModel = PackageInjectionViewModel(package: Package.samplePackage())
    viewModel.isLoading = true
    return NavigationView {
        PackageInjectionView(viewModel: viewModel)
    }
}

#Preview("Empty") {
    let viewModel = PackageInjectionViewModel(package: Package.samplePackage())
    viewModel.installedApps = []
    return NavigationView {
        PackageInjectionView(viewModel: viewModel)
    }
}
