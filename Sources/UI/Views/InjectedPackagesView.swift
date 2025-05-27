import SwiftUI

struct InjectedPackagesView: View {
    @StateObject private var viewModel = InjectedPackagesViewModel()
    @State private var showingInjectionView = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var selectedPackage: Package?
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading injected packages...")
                } else if viewModel.injectedPackages.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 50))
                            .foregroundColor(.accentColor)
                        Text("No Injected Packages")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("You haven't injected any packages yet.")
                            .foregroundColor(.secondary)
                        
                        Button(action: { showingInjectionView = true }) {
                            Label("Inject Package", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.top, 20)
                        .padding(.horizontal, 40)
                    }
                    .multilineTextAlignment(.center)
                    .padding()
                } else {
                    List {
                        ForEach(viewModel.injectedPackages) { package in
                            NavigationLink(destination: InjectedPackageDetailView(package: package)) {
                                InjectedPackageRow(package: package)
                            }
                        }
                        .onDelete(perform: viewModel.deletePackages)
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Injected Packages")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingInjectionView = true }) {
                        Image(systemName: "plus")
                    }
                }
                
                if !viewModel.injectedPackages.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingInjectionView) {
                NavigationView {
                    PackageInjectionView(package: selectedPackage ?? .mock())
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                Task {
                    do {
                        try await viewModel.loadInjectedPackages()
                    } catch {
                        errorMessage = "Failed to load injected packages: \(error.localizedDescription)"
                        showingError = true
                    }
                }
            }
        }
    }
}

struct InjectedPackageRow: View {
    let package: Package
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = package.icon {
                Image(uiImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .cornerRadius(8)
            } else {
                Image(systemName: "cube.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 40, height: 40)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(package.displayName)
                    .font(.headline)
                
                if let appName = package.injectedIntoApp {
                    HStack(spacing: 4) {
                        Image(systemName: "app")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(appName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let injectionDate = package.injectionDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(injectionDate, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let date = package.injectionDate {
                    Text("Injected \(date, style: .relative) ago")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if package.isInjected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

struct InjectedPackageDetailView: View {
    let package: Package
    @State private var showDeinjectConfirmation = false
    @State private var isDeinjecting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    private let packageManager = PackageManager.shared
    
    var body: some View {
        List {
            Section(header: Text("Package Info")) {
                HStack {
                    Image(systemName: "cube.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                        .frame(width: 40, height: 40)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(package.displayName)
                            .font(.headline)
                        Text("Version \(package.version)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 8)
                }
                .padding(.vertical, 4)
                
                if let description = package.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(description)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            if let appName = package.injectedIntoApp {
                Section(header: Text("Injection Info")) {
                    InfoRow(icon: "app", title: "Target App", value: appName)
                    
                    if let date = package.injectionDate {
                        InfoRow(icon: "calendar", title: "Injected", value: date.formatted())
                    }
                }
            }
            
            Section {
                Button(role: .destructive) {
                    showDeinjectConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Deinject Package", systemImage: "arrow.uturn.backward")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle(package.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Deinject Package", isPresented: $showDeinjectConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Deinject Package", role: .destructive) {
                Task {
                    isDeinjecting = true
                    defer { isDeinjecting = false }
                    
                    do {
                        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                            packageManager.deinject(package: package) { result in
                                switch result {
                                case .success():
                                    package.isInjected = false
                                    package.injectedIntoApp = nil
                                    package.injectionDate = nil
                                    continuation.resume()
                                    dismiss()
                                    
                                case .failure(let error):
                                    errorMessage = "Failed to deinject package: \(error.localizedDescription)"
                                    showError = true
                                    continuation.resume(throwing: error)
                                }
                            }
                        }
                    } catch {
                        // Error is already handled in the completion handler
                    }
                }
            }
            .disabled(isDeinjecting)
        } message: {
            Text("Are you sure you want to deinject this package? This will remove it from the target app.")
        }
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Label {
                Text(title)
                    .foregroundColor(.primary)
            } icon: {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
            }
            
            Spacer()
            
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Preview

struct InjectedPackagesView_Previews: PreviewProvider {
    static var previews: some View {
        InjectedPackagesView()
            .environmentObject(PackageManager.shared)
    }
}
