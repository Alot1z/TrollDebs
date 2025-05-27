import Foundation
import UIKit

/// Represents the source of a package
public enum PackageSource: String, Codable {
    case local
    case repository
    case unknown
    
    public var description: String {
        switch self {
        case .local: return "Local File"
        case .repository: return "Repository"
        case .unknown: return "Unknown"
        }
    }
}

/// Represents a Debian package with its metadata and dependencies
public struct Package: Identifiable, Codable, Hashable, Equatable, CustomStringConvertible {
    
    // MARK: - Package Action
    
    /// Represents possible actions that can be performed on a package
    public enum PackageAction: String, CaseIterable {
        case install = "Install"
        case remove = "Remove"
        case upgrade = "Upgrade"
        case reinstall = "Reinstall"
        case inject = "Inject into App"
        case showDetails = "Show Details"
        
        var systemImage: String {
            switch self {
            case .install: return "arrow.down.circle"
            case .remove: return "trash"
            case .upgrade: return "arrow.up.circle"
            case .reinstall: return "arrow.clockwise"
            case .inject: return "cube.transparent"
            case .showDetails: return "info.circle"
            }
        }
        
        var isDestructive: Bool {
            switch self {
            case .remove: return true
            default: return false
            }
        }
    }
    // MARK: - Properties
    
    /// Unique identifier for the package (same as name in Debian)
    public var id: String { identifier }
    
    /// Package identifier (same as name in Debian)
    public let identifier: String
    
    /// Display name of the package
    public let name: String
    
    /// Version string
    public let version: String
    
    /// Package description
    public let description: String
    
    /// Original author of the software
    public let author: String?
    
    /// Category section this package belongs to
    public let section: String?
    
    /// Target architecture (e.g., iphoneos-arm64)
    public let architecture: String
    
    /// Current maintainer of the package
    public let maintainer: String?
    
    /// List of package dependencies
    public let depends: [String]?
    
    /// List of conflicting packages
    public let conflicts: [String]?
    
    /// List of virtual packages this provides
    public let provides: [String]?
    
    /// Installed size in KB
    public let installedSize: Int?
    
    /// Original filename of the .deb file
    public let filename: String?
    
    /// Size of the package file in bytes
    public let size: Int?
    
    // MARK: - Computed Properties
    
    /// Formatted installed size (e.g., "1.2 MB")
    public var formattedSize: String {
        guard let size = installedSize, size > 0 else { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: Int64(size) * 1024, countStyle: .file)
    }
    
    /// Formatted package size if available
    public var formattedPackageSize: String {
        guard let size = fileSize, size > 0 else { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
    
    /// Whether the package is currently injected into an app
    public var isInjected: Bool = false
    
    /// The bundle identifier of the app this package is injected into, if any
    public var injectedIntoApp: String?
    
    /// The date when the package was last injected, if applicable
    public var injectionDate: Date?
    
    /// The display name of the app this package is injected into, if any
    public var injectedAppName: String?
    
    /// URL to the package file
    public let fileURL: URL
    
    /// The source of the package (e.g., local file, repository)
    public let source: PackageSource
    
    /// Whether the package is currently installed
    public let isInstalled: Bool
    
    /// The latest available version of the package, if different from the installed version
    public let latestVersion: String?
    
    /// Display name without version
    public var displayName: String {
        return name.components(separatedBy: ".").last ?? name
    }
    
    /// Display name with version
    public var displayNameWithVersion: String {
        return "\(displayName) (\(version))"
    }
    
    /// Detailed description with metadata
    public var detailedDescription: String {
        var details = [String]()
        
        if let author = author, !author.isEmpty {
            details.append("Author: \(author)")
        }
        
        if let section = section, !section.isEmpty {
            details.append("Section: \(section)")
        }
        
        details.append("Version: \(version)")
        details.append("Architecture: \(architecture)")
        details.append("Installed Size: \(formattedSize)")
        
        if let size = fileSize, size > 0 {
            details.append("Download Size: \(formattedPackageSize)")
        }
        
        if let maintainer = maintainer, !maintainer.isEmpty {
            details.append("Maintainer: \(maintainer)")
        }
        
        if let filename = filename, !filename.isEmpty {
            details.append("Filename: \(filename)")
        }
        
        // Add a separator before the description
        if !details.isEmpty {
            details.append(""\(description)"")
        } else {
            details.append(description)
        }
        
        // Add dependencies and conflicts if they exist
        if let depends = depends, !depends.isEmpty {
            details.append("\nDependencies:")
            depends.forEach { details.append(" • \($0)") }
        }
        
        if let conflicts = conflicts, !conflicts.isEmpty {
            details.append("\nConflicts with:")
            conflicts.forEach { details.append(" • \($0)") }
        }
        
        if let provides = provides, !provides.isEmpty {
            details.append("\nProvides:")
            provides.forEach { details.append(" • \($0)") }
        }
        
        return details.joined(separator: "\n")
    }
    
    /// Returns the file size in bytes if available
    public var fileSize: Int? {
        // If we have a filename, try to get the actual file size
        if let filename = self.filename, !filename.isEmpty {
            let fileManager = FileManager.default
            let filePath = "/var/lib/dpkg/info/\(filename)"
            
            if fileManager.fileExists(atPath: filePath) {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: filePath)
                    return attributes[.size] as? Int
                } catch {
                    return nil
                }
            }
        }
        return nil
    }
    
    /// Returns the installation date if available
    public var installationDate: Date? {
        guard let filename = self.filename, !filename.isEmpty else { return nil }
        let statusFile = "/var/lib/dpkg/info/\(filename).list"
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: statusFile)
            return attributes[.creationDate] as? Date
        } catch {
            return nil
        }
    }
    
    /// Formatted installation date
    public var formattedInstallationDate: String {
        guard let date = installationDate else { return "Unknown" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        return formatter.string(from: date)
    }
    
    // MARK: - Initialization
    
    public init(
        id: String,
        name: String,
        description: String,
        author: String?,
        version: String,
        section: String?,
        installedSize: Int?,
        installedDate: Date?,
        isInstalled: Bool,
        isInjected: Bool = false,
        injectedIntoApp: String? = nil,
        injectedAppName: String? = nil,
        injectionDate: Date? = nil,
        fileURL: URL = URL(fileURLWithPath: "/"),
        source: PackageSource = .unknown,
        latestVersion: String? = nil,
        architecture: String = "iphoneos-arm64",
        maintainer: String? = nil,
        depends: [String]? = nil,
        conflicts: [String]? = nil,
        provides: [String]? = nil,
        filename: String? = nil,
        size: Int? = nil
    ) {
        self.identifier = id
        self.name = name
        self.version = version
        self.description = description
        self.author = author
        self.section = section
        self.architecture = architecture
        self.maintainer = maintainer
        self.depends = depends
        self.conflicts = conflicts
        self.provides = provides
        self.installedSize = installedSize
        self.filename = filename
        self.size = size
        self.source = source
        self.isInstalled = isInstalled
        self.latestVersion = latestVersion
        self.fileURL = fileURL
        self.isInjected = isInjected
        self.injectedIntoApp = injectedIntoApp
        self.injectedAppName = injectedAppName
        self.injectionDate = injectionDate
        self.architecture = "iphoneos-arm64" // Default architecture
        self.maintainer = nil
        self.depends = nil
        self.conflicts = nil
        self.provides = nil
        self.installedSize = installedSize
        self.filename = nil
        self.size = nil
        self.fileURL = fileURL
        self.isInjected = isInjected
        self.injectedIntoApp = injectedIntoApp
        self.injectedAppName = injectedAppName
        self.injectionDate = injectionDate
    }
    
    // MARK: - Hashable & Equatable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
        hasher.combine(version)
    }
    
    public static func == (lhs: Package, rhs: Package) -> Bool {
        return lhs.identifier == rhs.identifier && lhs.version == rhs.version
    }
    
    // MARK: - CustomStringConvertible
    
    public var description: String {
        return "\(name) (\(version)) - \(description)"
    }
    
    /// Creates a copy of the package with updated injection status
    public func withInjection(into appBundleId: String, appName: String? = nil) -> Package {
        var newPackage = self
        newPackage.isInjected = true
        newPackage.injectedIntoApp = appBundleId
        newPackage.injectedAppName = appName
        newPackage.injectionDate = Date()
        return newPackage
    }
    
    /// Creates a copy of the package with injection removed
    public func withoutInjection() -> Package {
        var newPackage = self
        newPackage.isInjected = false
        newPackage.injectedIntoApp = nil
        newPackage.injectedAppName = nil
        newPackage.injectionDate = nil
        return newPackage
    }
}

// MARK: - Injection Database

private class InjectionDatabase {
    static let shared = InjectionDatabase()
    private let fileURL: URL
    private var database: [String: InjectionInfo]
    
    private struct InjectionInfo: Codable {
        let packageId: String
        let appBundleId: String
        let appName: String
        let injectionDate: Date
        let files: [String]  // List of injected files
        
        init(packageId: String, appBundleId: String, appName: String, injectionDate: Date, files: [String] = []) {
            self.packageId = packageId
            self.appBundleId = appBundleId
            self.appName = appName
            self.injectionDate = injectionDate
            self.files = files
        }
    }
    
    private init() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        fileURL = paths[0].appendingPathComponent("injection_database.json")
        
        // Load existing database or create new one
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: InjectionInfo].self, from: data) {
            database = decoded
        } else {
            database = [:]
        }
    }
    
    func isPackageInjected(identifier: String) -> Bool {
        return database[identifier] != nil
    }
    
    func getInjectionInfo(for packageId: String) -> (appBundleId: String, appName: String, injectionDate: Date, files: [String])? {
        guard let info = database[packageId] else { return nil }
        return (info.appBundleId, info.appName, info.injectionDate, info.files)
    }
    
    func getAllInjectedPackages() -> [Package] {
        return database.values.map { info in
            // Create a minimal package with injection info
            var package = Package(
                identifier: info.packageId,
                name: info.packageId.components(separatedBy: ".").last ?? info.packageId,
                version: "1.0",
                description: "Injected package",
                architecture: "iphoneos-arm64",
                isInjected: true,
                injectedIntoApp: info.appBundleId,
                injectionDate: info.injectionDate
            )
            return package
        }
    }
    
    func addInjection(packageId: String, appBundleId: String, appName: String, date: Date = Date(), files: [String] = []) {
        let info = InjectionInfo(
            packageId: packageId,
            appBundleId: appBundleId,
            appName: appName,
            injectionDate: date,
            files: files
        )
        
        database[packageId] = info
        saveDatabase()
    }
    
    // recordInjection is kept for backward compatibility
    func recordInjection(packageIdentifier: String, appBundleId: String, injectedFiles: [String]) {
        addInjection(
            packageId: packageIdentifier,
            appBundleId: appBundleId,
            appName: "Unknown App",
            date: Date(),
            files: injectedFiles
        )
    }
    
    func removeInjection(packageId: String) {
        if database.removeValue(forKey: packageId) != nil {
            saveDatabase()
        }
    }
    
    // Overload for backward compatibility
    func removeInjection(packageIdentifier: String, appBundleId: String) {
        if let existing = database[packageIdentifier], existing.appBundleId == appBundleId {
            database.removeValue(forKey: packageIdentifier)
            saveDatabase()
        }
    }
    
    private func saveDatabase() {
        if let encoded = try? JSONEncoder().encode(database) {
            try? encoded.write(to: fileURL)
        }
    }
}

// MARK: - Sample Data

extension Package {
    /// Sample packages for preview and testing
    public static var samplePackages: [Package] {
        [
            Package(
                identifier: "com.example.package1",
                name: "Example Package",
                version: "1.0.0",
                description: "This is an example package for demonstration purposes with a longer description that might wrap to multiple lines to test the UI layout and text wrapping behavior.",
                author: "Example Author <author@example.com>",
                section: "System",
                architecture: "iphoneos-arm64",
                maintainer: "Maintainer Name <maintainer@example.com>",
                depends: ["firmware (>= 14.0)", "mobilesubstrate"],
                conflicts: ["com.example.oldpackage"],
                provides: ["example-package"],
                installedSize: 2048,
                filename: "example-package_1.0.0_iphoneos-arm64.deb",
                size: 1024000
            ),
            Package(
                identifier: "com.example.tweak",
                name: "Example Tweak",
                version: "2.1.3",
                description: "A system customization tweak with many options and settings that can be configured through the Settings app.",
                author: "Tweak Developer <tweak@example.com>",
                section: "Tweaks",
                architecture: "iphoneos-arm64",
                maintainer: "Tweak Maintainer <maintainer@example.com>",
                depends: ["mobilesubstrate", "preferenceloader", "com.example.package1"],
                conflicts: ["com.other.tweak"],
                provides: ["example-tweak"],
                installedSize: 4096,
                filename: "example-tweak_2.1.3_iphoneos-arm64.deb",
                size: 2048000
            ),
            Package(
                identifier: "com.example.library",
                name: "Example Library",
                version: "1.5.2",
                description: "A shared library used by multiple packages with various features and optimizations.",
                author: "Library Team <library@example.com>",
                section: "Development",
                architecture: "iphoneos-arm64",
                maintainer: "Library Maintainer <maintainer@example.com>",
                depends: ["firmware (>= 13.0)"],
                conflicts: nil,
                provides: ["libexample"],
                installedSize: 1024,
                filename: "libexample_1.5.2_iphoneos-arm64.deb",
                size: 512000
            )
        ]
    }
}

// MARK: - Package Version Comparison

extension Package: Comparable {
    public static func < (lhs: Package, rhs: Package) -> Bool {
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}

// MARK: - Package Source

public enum PackageSource: String, Codable {
    case local
    case repository
    case file
    case unknown
    
    public var description: String {
        switch self {
        case .local: return "Installed"
        case .repository: return "Repository"
        case .file: return "Local File"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Package Action

public enum PackageAction: String, CaseIterable {
    case install = "Install"
    case remove = "Remove"
    case reinstall = "Reinstall"
    case upgrade = "Upgrade"
    case download = "Download"
    case showInfo = "Show Info"
    case showFiles = "Show Files"
    
    var systemImage: String {
        switch self {
        case .install: return "plus.circle"
        case .remove: return "trash"
        case .reinstall: return "arrow.clockwise"
        case .upgrade: return "arrow.up.circle"
        case .download: return "arrow.down.circle"
        case .showInfo: return "info.circle"
        case .showFiles: return "doc.text.magnifyingglass"
        }
    }
}
