import Foundation
import Combine

class PackageListViewModel: ObservableObject {
    @Published var packages: [Package] = []
    @Published var filteredPackages: [Package] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var error: Error?
    @Published var showingError: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let packageManager = PackageManager.shared
    
    init() {
        setupBindings()
        loadPackages()
    }
    
    private func setupBindings() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] searchText in
                self?.filterPackages(with: searchText)
            }
            .store(in: &cancellables)
        
        $error
            .map { $0 != nil }
            .assign(to: &$showingError)
    }
    
    func loadPackages() {
        isLoading = true
        
        do {
            packages = try packageManager.listInstalledPackages()
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            filterPackages(with: searchText)
            isLoading = false
        } catch {
            self.error = error
            self.isLoading = false
        }
    }
    
    func refresh() {
        loadPackages()
    }
    
    func installPackage(at url: URL) {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                try self.packageManager.installDebianPackage(at: url.path)
                
                DispatchQueue.main.async {
                    self.loadPackages()
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    func removePackage(_ package: Package) {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                try self.packageManager.removePackage(identifier: package.identifier)
                
                DispatchQueue.main.async {
                    self.loadPackages()
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    private func filterPackages(with searchText: String) {
        if searchText.isEmpty {
            filteredPackages = packages
        } else {
            filteredPackages = packages.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.identifier.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    func errorMessage() -> String {
        error?.localizedDescription ?? "An unknown error occurred"
    }
}
