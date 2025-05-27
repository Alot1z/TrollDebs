import Combine
import Foundation
import UIKit

enum InjectionError: LocalizedError {
    case appSelectionRequired
    case injectionFailed(String)
    case appNotFound
    
    var errorDescription: String? {
        switch self {
        case .appSelectionRequired:
            return "Please select an app to inject into"
        case .injectionFailed(let message):
            return "Injection failed: \(message)"
        case .appNotFound:
            return "Selected app not found"
        }
    }
}

@MainActor
class PackageInjectionViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var installedApps: [InstalledApp] = []
    @Published private(set) var selectedApp: InstalledApp?
    @Published private(set) var isLoading = false
    @Published private(set) var isInjecting = false
    @Published var searchText = ""
    
    // Filtered apps based on search text
    var filteredApps: [InstalledApp] {
        if searchText.isEmpty {
            return installedApps
        }
        return installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // MARK: - Private Properties
    
    private let package: Package
    private let packageManager = PackageManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Preview Support
    
    static var preview: PackageInjectionViewModel {
        let viewModel = PackageInjectionViewModel(package: .mock())
        viewModel.installedApps = [
            InstalledApp(id: "1", name: "App 1", bundleIdentifier: "com.example.app1", version: "1.0", icon: nil),
            InstalledApp(id: "2", name: "App 2", bundleIdentifier: "com.example.app2", version: "2.0", icon: nil)
        ]
        return viewModel
    }
    
    // MARK: - Mock Data
    
    /// Creates a mock view model for previews
    /// - Returns: A configured PackageInjectionViewModel
    static func mock() -> PackageInjectionViewModel {
        let viewModel = PackageInjectionViewModel(package: .mock())
        viewModel.installedApps = [
            InstalledApp(id: "1", name: "App 1", bundleIdentifier: "com.example.app1", version: "1.0", icon: nil),
            InstalledApp(id: "2", name: "App 2", bundleIdentifier: "com.example.app2", version: "2.0", icon: nil)
        ]
        return viewModel
    }
    
    // MARK: - Initialization
    
    init(package: Package) {
        self.package = package
    }
    
    // MARK: - Public Methods
    
    /// Loads the list of installed apps that can be injected into
    func loadInstalledApps() async throws {
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        let apps = try await packageManager.getInstalledApps()
        installedApps = apps.sorted { $0.name < $1.name }
    }
    
    /// Selects an app for injection
    /// - Parameter app: The app to select
    func selectApp(_ app: InstalledApp) {
        selectedApp = app
    }
    
    /// Injects the package into the selected app
    func injectPackage() async throws {
        guard let selectedApp = selectedApp else {
            throw InjectionError.appSelectionRequired
        }
        
        isInjecting = true
        defer { isInjecting = false }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            packageManager.inject(package: package, into: selectedApp) { result in
                switch result {
                case .success():
                    // Update the package's injection status
                    self.package.isInjected = true
                    self.package.injectedIntoApp = selectedApp.bundleIdentifier
                    self.package.injectionDate = Date()
                    
                    continuation.resume()
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func showError(message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = message
            self?.showError = true
            
            // Auto-dismiss error after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.showError = false
            }
        }
    }
    
    private func showSuccess(message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.successMessage = message
            self?.showSuccess = true
            
            // Auto-dismiss success after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.showSuccess = false
            }
        }
    }
    
    // MARK: - Models
    
    struct InstalledApp: Identifiable, Hashable {
        let bundleIdentifier: String
        let name: String
        let version: String?
        let icon: UIImage?
        
        // For Identifiable
        var id: String { bundleIdentifier }
        
        // For Hashable
        func hash(into hasher: inout Hasher) {
            hasher.combine(bundleIdentifier)
        }
        
        // For Equatable
        static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
            lhs.bundleIdentifier == rhs.bundleIdentifier
        }
    }
}
