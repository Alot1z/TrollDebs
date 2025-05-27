import Foundation

public enum PackageManagerError: Error {
    case packageNotFound
    case installationFailed(String)
    case removalFailed(String)
    case dependencyResolutionFailed
    case invalidPackage
    case fileOperationFailed
    case notAuthorized
}

public class PackageManager {
    public static let shared = PackageManager()
    
    private let fileManager = FileManager.default
    private let dpkgPath = "/usr/bin/dpkg"
    private let aptPath = "/usr/bin/apt"
    private let statusFile = "/var/lib/dpkg/status"
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Installs a Debian package from the specified path
    public func installDebianPackage(at path: String) throws {
        guard fileManager.fileExists(atPath: path) else {
            throw PackageManagerError.packageNotFound
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: dpkgPath)
        process.arguments = ["-i", path]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw PackageManagerError.installationFailed(errorMessage)
        }
    }
    
    /// Removes a package with the specified identifier
    public func removePackage(identifier: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: aptPath)
        process.arguments = ["remove", "--purge", "-y", identifier]
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw PackageManagerError.removalFailed(errorMessage)
        }
    }
    
    /// Lists all installed packages
    public func listInstalledPackages() throws -> [Package] {
        guard let statusData = fileManager.contents(atPath: statusFile) else {
            throw PackageManagerError.fileOperationFailed
        }
        
        guard let statusString = String(data: statusData, encoding: .utf8) else {
            throw PackageManagerError.fileOperationFailed
        }
        
        let packageStrings = statusString.components(separatedBy: "\n\n")
        var packages: [Package] = []
        
        for packageString in packageStrings {
            if let package = parsePackage(from: packageString) {
                packages.append(package)
            }
        }
        
        return packages
    }
    
    /// Gets information about a specific package
    public func getPackageInfo(identifier: String) throws -> Package? {
        let packages = try listInstalledPackages()
        return packages.first { $0.identifier == identifier }
    }
    
    // MARK: - Private Methods
    
    private func parsePackage(from packageString: String) -> Package? {
        var packageInfo: [String: String] = [:]
        
        let lines = packageString.components(separatedBy: .newlines)
        for line in lines {
            if let colonIndex = line.firstIndex(of: ":") {
                let key = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                packageInfo[key] = value
            }
        }
        
        guard let package = packageInfo["Package"],
              let version = packageInfo["Version"],
              let description = packageInfo["Description"] else {
            return nil
        }
        
        return Package(
            identifier: package,
            name: package,
            version: version,
            description: description,
            author: packageInfo["Author"],
            section: packageInfo["Section"],
            architecture: packageInfo["Architecture"] ?? "",
            maintainer: packageInfo["Maintainer"],
            depends: parseDependencies(packageInfo["Depends"]),
            conflicts: parseDependencies(packageInfo["Conflicts"]),
            provides: parseDependencies(packageInfo["Provides"]),
            installedSize: Int(packageInfo["Installed-Size"] ?? ""),
            filename: packageInfo["Filename"]
        )
    }
    
    private func parseDependencies(_ dependencyString: String?) -> [String]? {
        guard let dependencyString = dependencyString, !dependencyString.isEmpty else {
            return nil
        }
        
        // Split by commas and clean up version specifications
        return dependencyString.components(separatedBy: ",")
            .map { $0.components(separator: "|").first ?? $0 } // Take first alternative
            .map { $0.components(separator: "(").first ?? $0 } // Remove version info
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
