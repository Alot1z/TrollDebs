import Foundation
import Combine
import SwiftUI

@MainActor
class InjectedPackagesViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var injectedPackages: [Package] = []
    @Published private(set) var isLoading = false
    
    // MARK: - Private Properties
    
    private let packageManager = PackageManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Methods
    
    /// Loads the list of injected packages
    func loadInjectedPackages() async throws {
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        // Load packages from the package manager
        let packages = try await packageManager.getInjectedPackages()
        injectedPackages = packages.sorted { $0.displayName < $1.displayName }
    }
    
    /// Deletes the specified packages
    /// - Parameter offsets: The indices of the packages to delete
    func deletePackages(at offsets: IndexSet) async throws {
        let packagesToDelete = offsets.map { injectedPackages[$0] }
        
        for package in packagesToDelete {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                packageManager.removeInjectedPackage(package) { result in
                    switch result {
                    case .success():
                        Task { @MainActor [weak self] in
                            if let index = self?.injectedPackages.firstIndex(where: { $0.id == package.id }) {
                                self?.injectedPackages.remove(at: index)
                            }
                            continuation.resume()
                        }
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    /// Refreshes the list of injected packages
    func refresh() async throws {
        try await loadInjectedPackages()
    }
    
    // MARK: - Preview Support
    
    /// Creates a mock view model for previews
    /// - Returns: A configured InjectedPackagesViewModel
    static func mock() -> InjectedPackagesViewModel {
        let viewModel = InjectedPackagesViewModel()
        viewModel.injectedPackages = [
            Package.mock(),
            Package.mock().then { $0.displayName = "Another Package" }
        ]
        return viewModel
    }
}
