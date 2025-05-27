import Foundation
import UIKit

enum PackageManagerError: Error {
    case packageNotFound
    case installationFailed(String)
    case removalFailed(String)
    case injectionFailed(String)
    case extractionFailed
    case signingFailed
    case appNotFound
    case backupFailed
    case unsupportedPackageType
    case fileOperationFailed
    case notAuthorized
}

enum PackageType: String, Codable {
    case trollStore
    case system
    case user
}

class PackageManager {
    static let shared = PackageManager()
    
    private let fileManager = FileManager.default
    private let injectionDatabase = InjectionDatabase.shared
    private let backupManager = BackupManager.shared
    private let dpkgPath = "/usr/bin/dpkg"
    private let ldidPath = "/usr/bin/ldid"
    private let statusFile = "/var/lib/dpkg/status"
    
    // MARK: - Public Methods
    
    /// Get the installed version of a package
    /// - Parameter packageId: The package identifier
    /// - Returns: The installed version string or nil if not installed
    func installedVersion(of packageId: String) -> String? {
        // In a real implementation, this would query the package database
        // For now, we'll return a mock value
        return nil
    }
    
    /// Check if a package is installed
    /// - Parameter package: The package to check
    /// - Returns: True if the package is installed
    func isPackageInstalled(_ package: Package) -> Bool {
        // In a real implementation, this would check the package database
        // For now, we'll return a mock value
        return false
    }
    
    /// Get a list of all installed packages
    /// - Returns: Array of installed packages
    func listInstalledPackages() -> [Package] {
        // In a real implementation, this would query the package database
        // For now, we'll return an empty array
        return []
    }
    
    /// Get a list of all injected packages
    /// - Returns: Array of injected packages
    func listInjectedPackages() -> [Package] {
        return injectionDatabase.getAllInjectedPackages()
    }
    
    /// Get injected packages asynchronously
    /// - Returns: Array of injected packages
    func getInjectedPackages() async throws -> [Package] {
        return injectionDatabase.getAllInjectedPackages()
    }
    
    // MARK: - Package Installation
    
    /// Install a package
    /// - Parameters:
    ///   - package: The package to install
    ///   - completion: Completion handler with success/failure
    func install(_ package: Package, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                // 1. Extract package
                let tempDir = try await extractDeb(package.fileURL)
                
                // 2. Copy files to their destinations
                let applicationsDir = URL(fileURLWithPath: "/Applications")
                try await copyFiles(from: tempDir, to: applicationsDir)
                
                // 3. Update package database
                try await updatePackageDatabase()
                
                // 4. Clean up
                try? fileManager.removeItem(at: tempDir)
                
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    private func updatePackageDatabase() async throws {
        // Implementation to update package database
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/uicache")
        process.arguments = ["-p", "/Applications"]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw PackageManagerError.fileOperationFailed
        }
    }
    
    private func getInstalledFiles(for package: Package) async throws -> [URL] {
        // Implementation to get installed files for a package
        let listFile = "/var/lib/dpkg/info/\(package.id).list"
        guard let content = try? String(contentsOfFile: listFile, encoding: .utf8) else {
            return []
        }
        
        return content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: $0) }
    }
    
    // MARK: - Package Removal
    
    /// Remove a package
    /// - Parameters:
    ///   - package: The package to remove
    ///   - completion: Completion handler with success/failure
    func remove(_ package: Package, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                // 1. Check if package is injected
                if package.isInjected, let appBundleId = package.injectedIntoApp {
                    // If injected, deinject first
                    try await withCheckedThrowingContinuation { continuation in
                        deinject(package: package) { result in
                            switch result {
                            case .success:
                                continuation.resume()
                            case .failure(let error):
                                continuation.resume(throwing: error)
                            }
                        }
                    }
                }
                
                // 2. Remove package files
                let installedFiles = try await getInstalledFiles(for: package)
                for file in installedFiles {
                    try? fileManager.removeItem(at: file)
                }
                
                // 3. Update package database
                try await updatePackageDatabase()
                
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Package Injection
    
    /// Inject a package into an app
    /// - Parameters:
    ///   - package: The package to inject
    ///   - app: The app to inject into
    ///   - completion: Completion handler with success/failure
    func inject(package: Package, into app: InstalledApp, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                // 1. Verify the app is not already injected with this package
                if injectionDatabase.isPackageInjected(packageId: package.id) {
                    throw PackageManagerError.injectionFailed("This package is already injected into another app")
                }
                
                // 2. Create a backup of the app
                try await backupManager.createBackup(of: app)
                
                do {
                    // 3. Extract package files
                    let tempDir = try await extractPackageFiles(package: package)
                    
                    // 4. Copy files to the app bundle
                    let appBundleURL = app.bundleURL
                    try await copyFiles(from: tempDir, to: appBundleURL)
                    
                    // 5. Update app signature
                    try await updateSignature(for: app)
                    
                    // 6. Update package info in our database
                    try await updatePackageInfo(package, injectedInto: app)
                    
                    // 7. Clean up temporary files
                    try? fileManager.removeItem(at: tempDir)
                    
                    completion(.success(()))
                } catch {
                    // If anything fails, try to restore from backup
                    try? await backupManager.restoreBackup(for: app)
                    throw error
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    /// Deinject a package from an app
    /// - Parameters:
    ///   - package: The package to deinject
    ///   - completion: Completion handler with success/failure
    func deinject(package: Package, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let appBundleId = package.injectedIntoApp else {
            completion(.failure(NSError(domain: "PackageManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Package is not injected into any app"])))
            return
        }
        
        Task {
            do {
                // 1. Find the app
                let apps = try await getInstalledApps()
                guard let app = apps.first(where: { $0.bundleIdentifier == appBundleId }) else {
                    // If we can't find the app, just clean up the injection record
                    try await updatePackageInfo(package, injectedInto: nil)
                    completion(.success(()))
                    return
                }
                
                // 2. Get the list of injected files
                let injectedFiles = injectionDatabase.getInjectionInfo(for: package.id)?.files ?? []
                
                // 3. Remove the injected files
                for file in injectedFiles {
                    let fileURL = app.bundleURL.appendingPathComponent(file)
                    if fileManager.fileExists(atPath: fileURL.path) {
                        try fileManager.removeItem(at: fileURL)
                    }
                }
                
                // 4. Update app signature
                try await updateSignature(for: app)
                
                // 5. Update package info in our database
                try await updatePackageInfo(package, injectedInto: nil)
                
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    /// Deinject a package from an app asynchronously
    /// - Parameter package: The package to deinject
    func deinject(package: Package) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            deinject(package: package) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func createInstalledApp(from url: URL) async -> InstalledApp? {
        let bundle = Bundle(url: url)
        guard let bundleId = bundle?.bundleIdentifier,
              let infoDict = bundle?.infoDictionary,
              let displayName = infoDict["CFBundleDisplayName"] as? String ?? infoDict["CFBundleName"] as? String,
              let version = infoDict["CFBundleShortVersionString"] as? String,
              let executable = infoDict["CFBundleExecutable"] as? String else {
            return nil
        }
        
        return InstalledApp(
            id: bundleId,
            bundleIdentifier: bundleId,
            displayName: displayName,
            version: version,
            bundleURL: url,
            executablePath: url.appendingPathComponent(executable).path
        )
    }
    
    private func extractDeb(_ debURL: URL) async throws -> URL {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: dpkgPath)
        process.arguments = ["-x", debURL.path, tempDir.path]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw PackageManagerError.extractionFailed
        }
        
        return tempDir
    }
    
    private func copyFiles(from source: URL, to destination: URL) async throws {
        let contents = try fileManager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants]
        )
        
        for item in contents {
            let destinationURL = destination.appendingPathComponent(item.lastPathComponent)
            
            // Skip certain files that shouldn't be copied
            let filename = item.lastPathComponent
            if filename == "_" || filename.hasPrefix(".") {
                continue
            }
            
            // Check if it's a directory
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory), isDirectory.boolValue {
                // Create directory if it doesn't exist
                if !fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
                }
                
                // Recursively copy contents
                try await copyFiles(from: item, to: destinationURL)
            } else {
                // It's a file, copy it
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                
                try fileManager.copyItem(at: item, to: destinationURL)
                
                // Set appropriate permissions
                try fileManager.setAttributes(
                    [.posixPermissions: 0o755],
                    ofItemAtPath: destinationURL.path
                )
            }
        }
    }
    
    /// Get the list of files that would be injected for a package
    /// - Parameters:
    ///   - package: The package to check
    ///   - app: The target app
    /// - Returns: Array of relative file paths that would be injected
    private func getInjectedFiles(for package: Package, in app: InstalledApp) async throws -> [String] {
        let tempDir = try await extractPackageFiles(package: package)
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        // Get all files in the package
        let enumerator = fileManager.enumerator(
            at: tempDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        
        var files: [String] = []
        
        while let fileURL = enumerator?.nextObject() as? URL {
            let relativePath = fileURL.path.replacingOccurrences(of: tempDir.path + "/", with: "")
            
            // Skip certain files and directories
            if relativePath.hasPrefix(".") || 
               relativePath.hasPrefix("_") ||
               relativePath.hasSuffix("/") {
                continue
            }
            
            files.append(relativePath)
        }
        
        return files
    }
    
    private func updatePackageInfo(_ package: Package, injectedInto app: InstalledApp?) async throws {
        // Update the package's injection status in the database
        if let app = app {
            // Get the list of files that were injected
            let injectedFiles = try await getInjectedFiles(for: package, in: app)
            
            // Add or update the injection record
            _ = injectionDatabase.addInjection(
                packageId: package.id,
                appBundleId: app.bundleIdentifier,
                appName: app.displayName,
                files: injectedFiles
            )
            
            // Update the package's metadata
            package.isInjected = true
            package.injectionDate = Date()
            package.injectedIntoApp = app.bundleIdentifier
            package.injectedAppName = app.displayName
        } else {
            // Remove the injection record
            injectionDatabase.removeInjection(packageId: package.id)
            
            // Update the package's metadata
            package.isInjected = false
            package.injectionDate = nil
            package.injectedIntoApp = nil
            package.injectedAppName = nil
        }
    }
    
    /// Extract package files to a temporary directory
    /// - Parameter package: The package to extract
    /// - Returns: URL to the temporary directory containing the extracted files
    private func extractPackageFiles(package: Package) async throws -> URL {
        // Create a unique temporary directory
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("trolldebs-\(UUID().uuidString)")
        
        // Create the directory if it doesn't exist
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Determine the package type and extract accordingly
        if package.fileURL.pathExtension.lowercased() == "deb" {
            // Extract .deb package
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/dpkg")
            process.arguments = ["-x", package.fileURL.path, tempDir.path]
            
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                throw PackageManagerError.extractionFailed
            }
            
            return tempDir
        } else if package.fileURL.pathExtension.lowercased() == "zip" {
            // Extract .zip archive
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-o", package.fileURL.path, "-d", tempDir.path]
            
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                throw PackageManagerError.extractionFailed
            }
            
            return tempDir
        } else {
            throw PackageManagerError.unsupportedPackageType
        }
    }
    
    /// Get all apps that have the specified package injected
    /// - Parameter package: The package to check
    /// - Returns: Array of apps that have the package injected
    func getAppsWithInjectedPackage(_ package: Package) async -> [InstalledApp] {
        // Get all injection records for this package
        let allInjectedPackages = injectionDatabase.getAllInjectedPackages()
        let packageRecords = allInjectedPackages.filter { $0.packageId == package.id }
        
        // If no records found, return empty array
        guard !packageRecords.isEmpty else {
            return []
        }
        
        // Get all installed apps
        guard let allApps = try? await getInstalledApps() else {
            return []
        }
        
        // Create a set of bundle IDs from the injection records for faster lookup
        let injectedBundleIds = Set(packageRecords.map { $0.appBundleId })
        
        // Filter apps to only include those that have this package injected
        return allApps.filter { injectedBundleIds.contains($0.bundleIdentifier) }
    }
    
    /// Get all injected packages
    /// - Returns: Array of tuples containing the package and the app it's injected into
    func getAllInjectedPackages() async throws -> [(package: Package, app: InstalledApp)] {
        // Get all installed apps
        let allApps = try await getInstalledApps()
        
        // Create a dictionary for faster lookup of apps by bundle ID
        let appsByBundleId = Dictionary(uniqueKeysWithValues: allApps.map { ($0.bundleIdentifier, $0) })
        
        // Get all injection records
        let injectionRecords = injectionDatabase.getAllInjectedPackages()
        
        // Convert records to package-app tuples
        var result = [(package: Package, app: InstalledApp)]()
        
        for record in injectionRecords {
            // Find the app this package is injected into
            guard let app = appsByBundleId[record.appBundleId] else {
                // Skip if app is no longer installed
                continue
            }
            
            // Create a package object from the record
            let package = Package(
                id: record.packageId,
                name: record.packageId.components(separatedBy: ".").last ?? record.packageId,
                version: "1.0", // Default version since we might not have this info
                description: "Injected package",
                author: "",
                section: "",
                architecture: "iphoneos-arm64",
                maintainer: nil,
                depends: nil,
                conflicts: nil,
                provides: nil,
                installedSize: 0,
                filename: nil,
                size: nil,
                fileURL: URL(fileURLWithPath: ""), // Empty URL as we don't have the original file
                source: .local,
                isInstalled: true,
                latestVersion: nil,
                isInjected: true,
                injectedIntoApp: record.appBundleId,
                injectedAppName: record.appName,
                injectionDate: record.injectionDate
            )
            
            result.append((package, app))
        }
        
        return result
    }
    
    private func updateSignature(for app: InstalledApp) async throws {
        // First, ensure the app is writable
        try fileManager.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: app.bundleURL.path
        )
        
        // Use ldid to update signature with TrollStore's certificate
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ldidPath)
        process.arguments = [
            "-K", "/var/containers/Bundle/Application/*/trollstore.app/cert.der",
            "-M", // Preserve existing permissions
            "-s", // Sign the binary
            app.bundleURL.path
        ]
        
        let pipe = Pipe()
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw PackageManagerError.signingFailed("Failed to sign app: \(errorString)")
        }
        
        // Set correct permissions on the app bundle
        try fileManager.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: app.bundleURL.path
        )
        
        // Also ensure the main executable has the right permissions
        if let executablePath = app.executablePath {
            try fileManager.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: executablePath
            )
        }
    }
    
    private func scanForApps(at path: String, apps: inout [InstalledApp]) async throws {
        let contents = try fileManager.contentsOfDirectory(atPath: path)
        
        for item in contents {
            let fullPath = "\(path)/\(item)"
            var isDirectory: ObjCBool = false
            
            // Check if it's a directory and has an Info.plist
            if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory),
               isDirectory.boolValue,
               let infoPlist = NSDictionary(contentsOfFile: "\(fullPath)/Info.plist") {
                
                if let bundleId = infoPlist["CFBundleIdentifier"] as? String,
                   let bundleName = infoPlist["CFBundleDisplayName"] as? String ?? infoPlist["CFBundleName"] as? String {
                    
                    let version = infoPlist["CFBundleShortVersionString"] as? String
                    let executableName = (infoPlist["CFBundleExecutable"] as? String) ?? bundleName
                    
                    let app = InstalledApp(
                        id: bundleId,
                        bundleIdentifier: bundleId,
                        displayName: bundleName,
                        version: version ?? "",
                        bundleURL: URL(fileURLWithPath: fullPath),
                        executablePath: "\(fullPath)/\(executableName)"
                    )
                    
                    if !apps.contains(where: { $0.bundleIdentifier == bundleId }) {
                        apps.append(app)
                    }
                }
            }
        }
    }
    
            deinject(package: package) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    /// Deinject a package from an app by ID
    /// - Parameters:
    ///   - packageId: The package identifier
    ///   - bundleId: The bundle identifier of the target app
    /// - Throws: Error if deinjection fails
    func deinject(packageId: String, fromAppWithBundleId bundleId: String) async throws {
        // In a real implementation, this would perform the actual deinjection
        // For now, we'll just remove it from the database
        injectionDatabase.removeInjection(packageId: packageId)
    }
    
    // MARK: - Sample Data
    
    /// Get sample packages for preview and testing
    /// - Returns: Array of sample packages
    static var samplePackages: [Package] {
        [
            Package(
                identifier: "com.example.package1",
                name: "Sample Package 1",
                version: "1.0.0",
                description: "A sample package for testing purposes",
                author: "Example Author",
                section: "Development",
                architecture: "iphoneos-arm64",
                maintainer: "Maintainer Name",
                depends: [],
                conflicts: [],
                provides: [],
                installedSize: 1024,
                filename: "sample1.deb",
                size: 2048
            ),
            Package(
                identifier: "com.example.package2",
                name: "Sample Package 2",
                version: "2.0.0",
                description: "Another sample package for testing",
                author: "Another Author",
                section: "System",
                architecture: "iphoneos-arm64",
                maintainer: "Maintainer Name",
                depends: ["com.example.package1"],
                conflicts: [],
                provides: [],
                installedSize: 2048,
                filename: "sample2.deb",
                size: 4096
            )
        ]
    }
}
