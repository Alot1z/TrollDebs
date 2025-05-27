import Foundation

struct InjectionRecord: Codable, Identifiable {
    let id: String
    let packageId: String
    let appBundleId: String
    let appName: String
    let injectionDate: Date
    var files: [String]
    
    // Computed property for backward compatibility
    var packageIdentifier: String { packageId }
    
    init(packageId: String, appBundleId: String, appName: String, injectionDate: Date = Date(), files: [String] = []) {
        self.id = "\(packageId)_\(appBundleId)"
        self.packageId = packageId
        self.appBundleId = appBundleId
        self.appName = appName
        self.injectionDate = injectionDate
        self.files = files
    }
}

class InjectionDatabase {
    static let shared = InjectionDatabase()
    
    private let fileURL: URL
    private var records: [String: InjectionRecord] // Keyed by ID
    private var packageToRecordId: [String: String] // Package ID to Record ID mapping
    
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // Notification names
    static let injectionAddedNotification = Notification.Name("InjectionDatabaseInjectionAdded")
    static let injectionRemovedNotification = Notification.Name("InjectionDatabaseInjectionRemoved")
    static let injectionUpdatedNotification = Notification.Name("InjectionDatabaseInjectionUpdated")
    
    private init() {
        // Set up file URL
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        fileURL = paths[0].appendingPathComponent("injection_database_v2.json")
        
        // Initialize with empty data
        records = [:]
        packageToRecordId = [:]
        
        // Load existing data
        loadDatabase()
    }
    
    // MARK: - Public Methods
    
    /// Check if a package is injected
    /// - Parameter packageId: The package identifier
    /// - Returns: True if the package is injected
    func isPackageInjected(packageId: String) -> Bool {
        return packageToRecordId[packageId] != nil
    }
    
    /// Get all injected packages
    /// - Returns: Array of all injection records
    func getAllInjectedPackages() -> [InjectionRecord] {
        return Array(records.values)
    }
    
    /// Get injection record for a package
    /// - Parameter packageId: The package identifier
    /// - Returns: Injection record if found, nil otherwise
    func getInjectionInfo(for packageId: String) -> InjectionRecord? {
        guard let recordId = packageToRecordId[packageId] else { return nil }
        return records[recordId]
    }
    
    /// Add a new injection record
    /// - Parameters:
    ///   - packageId: The package identifier
    ///   - appBundleId: The bundle identifier of the target app
    ///   - appName: The display name of the target app
    ///   - files: List of injected files (optional)
    /// - Returns: The created injection record
    @discardableResult
    func addInjection(packageId: String, 
                    appBundleId: String, 
                    appName: String, 
                    files: [String] = []) -> InjectionRecord {
        let record = InjectionRecord(
            packageId: packageId,
            appBundleId: appBundleId,
            appName: appName,
            files: files
        )
        
        // Update our in-memory storage
        records[record.id] = record
        packageToRecordId[packageId] = record.id
        
        // Persist to disk
        saveDatabase()
        
        // Notify observers
        NotificationCenter.default.post(
            name: InjectionDatabase.injectionAddedNotification,
            object: nil,
            userInfo: ["record": record]
        )
        
        return record
    }
    
    /// Remove an injection record
    /// - Parameter packageId: The package identifier to remove
    func removeInjection(packageId: String) {
        guard let recordId = packageToRecordId[packageId],
              let record = records[recordId] else { return }
        
        // Update our in-memory storage
        records.removeValue(forKey: recordId)
        packageToRecordId.removeValue(forKey: packageId)
        
        // Persist to disk
        saveDatabase()
        
        // Notify observers
        NotificationCenter.default.post(
            name: InjectionDatabase.injectionRemovedNotification,
            object: nil,
            userInfo: ["record": record]
        )
    }
    
    /// Update files for an existing injection
    /// - Parameters:
    ///   - packageId: The package identifier
    ///   - files: The updated list of files
    /// - Returns: The updated injection record if successful
    @discardableResult
    func updateInjectionFiles(packageId: String, files: [String]) -> InjectionRecord? {
        guard let recordId = packageToRecordId[packageId],
              var record = records[recordId] else { return nil }
        
        // Update the record
        record.files = files
        records[recordId] = record
        
        // Persist to disk
        saveDatabase()
        
        // Notify observers
        NotificationCenter.default.post(
            name: InjectionDatabase.injectionUpdatedNotification,
            object: nil,
            userInfo: ["record": record]
        )
        
        return record
    }
    
    // MARK: - Private Methods
    
    private func loadDatabase() {
        // Try to load from disk
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            // No existing database, start fresh
            records = [:]
            packageToRecordId = [:]
            return
        }
        
        do {
            // Try to decode the new format first
            let decodedRecords = try decoder.decode([String: InjectionRecord].self, from: data)
            
            // Successfully decoded new format
            records = decodedRecords
            
            // Rebuild the package ID to record ID mapping
            packageToRecordId = [String: String](
                uniqueKeysWithValues: records.values.map { ($0.packageId, $0.id) }
            )
        } catch {
            print("Failed to decode injection database: \(error)")
            // Fall back to empty database
            records = [:]
            packageToRecordId = [:]
        }
    }
    
    private func saveDatabase() {
        do {
            let data = try encoder.encode(records)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("Failed to save injection database: \(error)")
        }
    }
}
