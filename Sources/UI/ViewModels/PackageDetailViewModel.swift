import Foundation
import Combine
import UIKit

enum PackageError: LocalizedError {
    case installationFailed(String)
    case removalFailed(String)
    case invalidPackage
    
    var errorDescription: String? {
        switch self {
        case .installationFailed(let message):
            return "Installation failed: \(message)"
        case .removalFailed(let message):
            return "Removal failed: \(message)"
        case .invalidPackage:
            return "Invalid package"
        }
    }
}

@MainActor
class PackageDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var package: Package
    @Published private(set) var isInstalling = false
    @Published private(set) var isRemoving = false
    @Published private(set) var isRefreshing = false
    
    // Indicates if the view should be dismissed after an action
    @Published private(set) var shouldDismissView = false
    
    // MARK: - Private Properties
    
    private let packageManager = PackageManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(package: Package) {
        self.package = package
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    /// Installs or upgrades the package
    func installPackage() async throws {
        guard !isInstalling else { return }
        
        isInstalling = true
        defer { isInstalling = false }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            packageManager.install(package: package) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success():
                        self?.package.isInstalled = true
                        self?.package.installDate = Date()
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    /// Removes the package
    func removePackage() async throws {
        guard !isRemoving else { return }
        
        isRemoving = true
        defer { isRemoving = false }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            packageManager.remove(package: package) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success():
                        self?.package.isInstalled = false
                        self?.package.installDate = nil
                        self?.shouldDismissView = true
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    // MARK: - Package Actions
    
    /// Refreshes the package details
    func refreshPackage() async {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        defer { isRefreshing = false }
        
        // Refresh package details from the package manager
        if let updatedPackage = await packageManager.getPackage(identifier: package.identifier) {
            package = updatedPackage
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe changes to the package (e.g., after installation/removal)
        $package
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Helper Methods
    
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
    
    // MARK: - File Browser
    
    func browseFiles() {
        showFileBrowser = true
    }
}

// MARK: - Preview Extensions

extension PackageDetailViewModel {
    static var preview: PackageDetailViewModel {
        let package = Package.sampleInjectedPackage
        return PackageDetailViewModel(package: package)
    }
}
