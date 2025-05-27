import Foundation

class BackupManager {
    static let shared = BackupManager()
    private let fileManager = FileManager.default
    private let backupsDir = URL(fileURLWithPath: "/var/mobile/Library/TrollDebs/Backups")
    
    private init() {
        // Create backups directory if it doesn't exist
        try? fileManager.createDirectory(
            at: backupsDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    func createBackup(of app: InstalledApp) async throws {
        let backupDir = backupsDir.appendingPathComponent("\(app.bundleIdentifier)_\(Date().timeIntervalSince1970)")
        
        // Create backup directory
        try fileManager.createDirectory(
            at: backupDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Copy app bundle to backup directory
        let appBackupDir = backupDir.appendingPathComponent(app.bundleURL.lastPathComponent)
        try fileManager.copyItem(at: app.bundleURL, to: appBackupDir)
        
        // Save metadata
        let metadata = BackupMetadata(
            appBundleId: app.bundleIdentifier,
            originalPath: app.bundleURL.path,
            backupDate: Date(),
            backupLocation: appBackupDir
        )
        
        let encoder = JSONEncoder()
        let metadataData = try encoder.encode(metadata)
        try metadataData.write(to: backupDir.appendingPathComponent("metadata.json"))
    }
    
    func restoreBackup(for app: InstalledApp) async throws {
        // Find the latest backup for this app
        guard let backupDir = try findLatestBackup(for: app.bundleIdentifier) else {
            throw BackupError.backupNotFound
        }
        
        // Read metadata
        let metadataURL = backupDir.appendingPathComponent("metadata.json")
        let metadataData = try Data(contentsOf: metadataURL)
        let metadata = try JSONDecoder().decode(BackupMetadata.self, from: metadataData)
        
        // Remove current app
        try? fileManager.removeItem(at: app.bundleURL)
        
        // Restore from backup
        let appBackupDir = backupDir.appendingPathComponent(metadata.originalPath.components(separatedBy: "/").last!)
        try fileManager.copyItem(at: appBackupDir, to: app.bundleURL)
        
        // Clean up
        try? fileManager.removeItem(at: backupDir)
    }
    
    private func findLatestBackup(for bundleId: String) throws -> URL? {
        let backupDirs = try fileManager.contentsOfDirectory(
            at: backupsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )
        
        let appBackups = backupDirs.filter { $0.lastPathComponent.hasPrefix("\(bundleId)_") }
        
        return appBackups.max(by: {
            let date1 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let date2 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return date1 < date2
        })
    }
}

// MARK: - Models

struct BackupMetadata: Codable {
    let appBundleId: String
    let originalPath: String
    let backupDate: Date
    let backupLocation: URL
}

enum BackupError: LocalizedError {
    case backupNotFound
    case backupFailed
    case restoreFailed
    
    var errorDescription: String? {
        switch self {
        case .backupNotFound: return "Backup not found"
        case .backupFailed: return "Failed to create backup"
        case .restoreFailed: return "Failed to restore from backup"
        }
    }
}
