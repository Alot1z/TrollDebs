import Foundation
import UIKit
import MachO

class PackageInjector {
    
    // MARK: - Types
    
    enum InjectionError: Error, LocalizedError {
        case invalidAppBundle
        case invalidDebFile
        case extractionFailed
        case fileCopyFailed
        case injectionFailed
        case deinjectionFailed
        case appRestartFailed
        case notImplemented
        
        var errorDescription: String? {
            switch self {
            case .invalidAppBundle: return "Invalid application bundle"
            case .invalidDebFile: return "Invalid .deb file"
            case .extractionFailed: return "Failed to extract .deb file"
            case .fileCopyFailed: return "Failed to copy files"
            case .injectionFailed: return "Failed to inject package"
            case .deinjectionFailed: return "Failed to deinject package"
            case .appRestartFailed: return "Failed to restart application"
            case .notImplemented: return "Feature not implemented"
            }
        }
    }
    static let shared = PackageInjector()
    
    private let fileManager = FileManager.default
    private let bundle = Bundle.main
    
    // Paths to required binaries
    private let ldidPath = "/var/jb/usr/bin/ldid"
    private let dpkgPath = "/usr/bin/dpkg-deb"
    private let injectorPath = "/usr/bin/inject"
    private let sbreloadPath = "/usr/bin/sbreload"
    
    // File system paths
    private let trollStoreAppsPath = "/var/containers/Bundle/Application"
    private let debianDocsPath = "/var/lib/dpkg/info"
    private let libraryPath = "/var/mobile/Library"
    
    // File extensions to inject
    private let injectableExtensions: Set<String> = ["dylib", "bundle", "framework"]
    
    // Files to exclude from injection
    private let excludedFiles: Set<String> = [
        "System",
        "Library",
        "usr",
        "private",
        "var",
        "bin",
        "sbin",
        "etc",
        "Applications"
    ]
    
    // MARK: - Public Methods
    
    /// Injects a .deb package into an existing app
    /// - Parameters:
    ///   - debPath: Path to the .deb file
    ///   - targetBundleId: Bundle ID of the target app
    ///   - completion: Completion handler with success/failure
    func injectDeb(_ debPath: String, toAppWithBundleId targetBundleId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // 1. Verify the .deb file exists
        guard fileManager.fileExists(atPath: debPath) else {
            completion(.failure(InjectionError.invalidDebFile))
            return
        }
        
        // 2. Find the target app bundle
        findApp(bundleId: targetBundleId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let appBundle):
                // 3. Create a backup of the app if it doesn't exist
                self.createBackupIfNeeded(appBundle: appBundle) { backupResult in
                    switch backupResult {
                    case .success():
                        // 4. Extract the .deb file
                        self.extractDeb(debPath) { extractResult in
                            switch extractResult {
                            case .success(let tempDir):
                                // 5. Copy files from .deb to the app bundle
                                self.copyFiles(from: tempDir, to: appBundle) { copyResult in
                                    // Clean up temp directory
                                    try? self.fileManager.removeItem(atPath: tempDir)
                                    
                                    switch copyResult {
                                    case .success(let injectedFiles):
                                        // 6. Update injection database
                                        InjectionDatabase.shared.addInjection(
                                            packageId: (debPath as NSString).lastPathComponent,
                                            appBundleId: targetBundleId,
                                            files: injectedFiles
                                        )
                                        
                                        // 7. Resign the app if needed
                                        self.resignAppIfNeeded(appBundle: appBundle) { signResult in
                                            switch signResult {
                                            case .success():
                                                // 8. Restart the app
                                                self.restartApp(bundleId: targetBundleId) { restartResult in
                                                    completion(restartResult)
                                                }
                                            case .failure(let error):
                                                completion(.failure(error))
                                            }
                                        }
                                    case .failure(let error):
                                        completion(.failure(error))
                                    }
                                }
                            case .failure(let error):
                                completion(.failure(error))
                            }
                        }
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Deinjects a previously injected package
    /// - Parameters:
    ///   - packageId: The package identifier to deinject
    ///   - targetBundleId: The target app's bundle ID
    ///   - completion: Completion handler with success/failure
    func deinject(packageId: String, fromAppWithBundleId targetBundleId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // 1. Find the target app bundle
        findApp(bundleId: targetBundleId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let appBundle):
                // 2. Get the list of injected files from the database
                guard let injectionInfo = InjectionDatabase.shared.getInjectionInfo(for: packageId) else {
                    completion(.failure(InjectionError.deinjectionFailed))
                    return
                }
                
                // 3. Restore the app from backup
                self.restoreFromBackup(appBundle: appBundle) { restoreResult in
                    switch restoreResult {
                    case .success():
                        // 4. Remove the injection record
                        InjectionDatabase.shared.removeInjection(packageId: packageId)
                        
                        // 5. Restart the app
                        self.restartApp(bundleId: targetBundleId) { restartResult in
                            completion(restartResult)
                        }
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func createBackupIfNeeded(appBundle: Bundle, completion: @escaping (Result<Void, Error>) -> Void) {
        let backupPath = "\(libraryPath)/Caches/TrollDebs/Backups/\(appBundle.bundleIdentifier ?? "unknown")"
        
        // Check if backup already exists
        if fileManager.fileExists(atPath: backupPath) {
            completion(.success(()))
            return
        }
        
        // Create backup directory
        do {
            try fileManager.createDirectory(atPath: backupPath, withIntermediateDirectories: true)
            
            // Copy the app bundle to the backup location
            let appName = (appBundle.bundlePath as NSString).lastPathComponent
            let backupAppPath = "\(backupPath)/\(appName)"
            
            try fileManager.copyItem(atPath: appBundle.bundlePath, toPath: backupAppPath)
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
    
    private func restoreFromBackup(appBundle: Bundle, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let bundleId = appBundle.bundleIdentifier else {
            completion(.failure(InjectionError.invalidAppBundle))
            return
        }
        
        let backupPath = "\(libraryPath)/Caches/TrollDebs/Backups/\(bundleId)"
        let appName = (appBundle.bundlePath as NSString).lastPathComponent
        let backupAppPath = "\(backupPath)/\(appName)"
        
        // Check if backup exists
        guard fileManager.fileExists(atPath: backupAppPath) else {
            completion(.failure(InjectionError.deinjectionFailed))
            return
        }
        
        do {
            // Remove the current app
            try fileManager.removeItem(atPath: appBundle.bundlePath)
            
            // Restore from backup
            try fileManager.copyItem(atPath: backupAppPath, toPath: appBundle.bundlePath)
            
            // Clean up backup
            try fileManager.removeItem(atPath: backupPath)
            
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
    
    private func extractDeb(_ debPath: String, completion: @escaping (Result<String, Error>) -> Void) {
        let tempDir = NSTemporaryDirectory() + "debextract_" + UUID().uuidString
        
        do {
            try fileManager.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
            
            // Extract the .deb file
            let process = Process()
            process.launchPath = dpkgPath
            process.arguments = ["-x", debPath, tempDir]
            
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe
            
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    completion(.success(tempDir))
                } else {
                    completion(.failure(InjectionError.extractionFailed))
                }
            }
            
            try process.run()
        } catch {
            completion(.failure(error))
        }
    }
    
    private func findApp(bundleId: String, completion: @escaping (Result<Bundle, Error>) -> Void) {
        // Search in TrollStore apps directory
        searchForApp(bundleId: bundleId, in: trollStoreAppsPath) { result in
            if case .success = result {
                completion(result)
            } else {
                // If not found, try the standard applications directory
                self.searchForApp(bundleId: bundleId, in: "/Applications") { result in
                    completion(result)
                }
            }
        }
    }
    
    private func searchForApp(bundleId: String, in directory: String, completion: @escaping (Result<Bundle, Error>) -> Void) {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else {
            completion(.failure(InjectionError.invalidAppBundle))
            return
        }
        
        for item in contents {
            let appPath = "\(directory)/\(item)"
            let infoPlistPath = "\(appPath)/Info.plist"
            
            // Check if this is a directory with an Info.plist
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: infoPlistPath, isDirectory: &isDir), !isDir.boolValue {
                if let infoDict = NSDictionary(contentsOfFile: infoPlistPath),
                   let appBundleId = infoDict["CFBundleIdentifier"] as? String,
                   appBundleId == bundleId {
                    
                    if let bundle = Bundle(path: appPath) {
                        completion(.success(bundle))
                        return
                    }
                }
            }
        }
        
        completion(.failure(InjectionError.invalidAppBundle))
    }
    
    private func copyFiles(from sourceDir: String, to appBundle: Bundle, completion: @escaping (Result<[String], Error>) -> Void) {
        let fileManager = self.fileManager
        var injectedFiles: [String] = []
        
        // Define the target directories for different file types
        let targetDirs: [String: String] = [
            "dylib": "Frameworks",
            "bundle": "Frameworks",
            "framework": "Frameworks",
            "plist": ""
        ]
        
        // Create necessary directories in the app bundle
        let frameworksDir = appBundle.bundleURL.appendingPathComponent("Frameworks")
        try? fileManager.createDirectory(at: frameworksDir, withIntermediateDirectories: true)
        
        // Function to process a directory recursively
        func processDirectory(at path: String, relativePath: String = "") throws {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            
            for item in contents {
                // Skip excluded files and directories
                if excludedFiles.contains(item) { continue }
                
                let fullPath = "\(path)/\(item)"
                let relativeItemPath = relativePath.isEmpty ? item : "\(relativePath)/\(item)"
                var isDirectory: ObjCBool = false
                
                guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory) else {
                    continue
                }
                
                if isDirectory.boolValue {
                    // Recursively process subdirectories
                    try processDirectory(at: fullPath, relativePath: relativeItemPath)
                } else {
                    // Process files
                    let fileExtension = (item as NSString).pathExtension.lowercased()
                    
                    // Skip files we don't care about
                    guard injectableExtensions.contains(fileExtension) else { continue }
                    
                    // Determine the target directory
                    let targetDir = targetDirs[fileExtension] ?? ""
                    let targetPath: String
                    
                    if targetDir.isEmpty {
                        targetPath = appBundle.bundlePath
                    } else {
                        targetPath = appBundle.bundleURL.appendingPathComponent(targetDir).path
                    }
                    
                    // Create target directory if it doesn't exist
                    try? fileManager.createDirectory(atPath: targetPath, withIntermediateDirectories: true)
                    
                    // Copy the file
                    let destinationPath = "\(targetPath)/\(item)"
                    try? fileManager.removeItem(atPath: destinationPath) // Remove if exists
                    try fileManager.copyItem(atPath: fullPath, toPath: destinationPath)
                    
                    // Set executable permissions
                    try fileManager.setAttributes(
                        [.posixPermissions: 0o755],
                        ofItemAtPath: destinationPath
                    )
                    
                    injectedFiles.append(destinationPath)
                    
                    // If this is a dylib, we need to inject it
                    if fileExtension == "dylib" {
                        injectDylib(at: destinationPath, to: appBundle)
                    }
                }
            }
        }
        
        do {
            try processDirectory(at: sourceDir)
            completion(.success(injectedFiles))
        } catch {
            completion(.failure(error))
        }
    }
    
    private func injectDylib(at path: String, to appBundle: Bundle) {
        // This is a simplified version - in a real implementation, you would:
        // 1. Parse the Mach-O header of the binary
        // 2. Add a new LC_LOAD_DYLIB command
        // 3. Update the header and commands
        // 
        // For now, we'll just log that we would inject the dylib
        print("Would inject dylib at \(path) into \(appBundle.bundleIdentifier ?? "unknown")")
    }
    
    private func resignAppIfNeeded(appBundle: Bundle, completion: @escaping (Result<Void, Error>) -> Void) {
        // Check if the app is signed with TrollStore
        // For TrollStore apps, we don't need to resign
        completion(.success(()))
    }
    
    private func restartApp(bundleId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Use sbreload to restart SpringBoard
        let process = Process()
        process.launchPath = sbreloadPath
        
        process.terminationHandler = { process in
            if process.terminationStatus == 0 {
                completion(.success(()))
            } else {
                completion(.failure(InjectionError.appRestartFailed))
            }
        }
        
        do {
            try process.run()
        } catch {
            completion(.failure(error))
        }
    }
}

// MARK: - Error Types

enum PackageInjectionError: Error, LocalizedError {
    case extractionFailed
    case appNotFound
    case injectionFailed
    case resigningFailed
    case restartFailed
    
    var errorDescription: String? {
        switch self {
        case .extractionFailed:
            return "Failed to extract the .deb package"
        case .appNotFound:
            return "Target app not found"
        case .injectionFailed:
            return "Failed to inject files into the app"
        case .resigningFailed:
            return "Failed to resign the app"
        case .restartFailed:
            return "Failed to restart the app"
        }
    }
}
