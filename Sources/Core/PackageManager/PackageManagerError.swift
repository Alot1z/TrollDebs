import Foundation

extension PackageManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .packageNotFound:
            return "The package file was not found at the specified path."
        case .installationFailed(let message):
            return "Package installation failed: \(message)"
        case .removalFailed(let message):
            return "Failed to remove package: \(message)"
        case .dependencyResolutionFailed:
            return "Failed to resolve package dependencies."
        case .invalidPackage:
            return "The specified file is not a valid package."
        case .fileOperationFailed:
            return "A file system operation failed."
        case .notAuthorized:
            return "You don't have permission to perform this operation."
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .packageNotFound:
            return "Please check the file path and try again."
        case .installationFailed, .removalFailed:
            return "Check the error message for details and try again."
        case .dependencyResolutionFailed:
            return "Make sure all dependencies are installed and try again."
        case .invalidPackage:
            return "The package might be corrupted. Try downloading it again."
        case .fileOperationFailed:
            return "Check if you have sufficient permissions and disk space, then try again."
        case .notAuthorized:
            return "Run the application with administrator privileges and try again."
        }
    }
}

// MARK: - Equatable

extension PackageManagerError: Equatable {
    public static func == (lhs: PackageManagerError, rhs: PackageManagerError) -> Bool {
        switch (lhs, rhs) {
        case (.packageNotFound, .packageNotFound):
            return true
        case (.installationFailed(let lhsMsg), .installationFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.removalFailed(let lhsMsg), .removalFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.dependencyResolutionFailed, .dependencyResolutionFailed):
            return true
        case (.invalidPackage, .invalidPackage):
            return true
        case (.fileOperationFailed, .fileOperationFailed):
            return true
        case (.notAuthorized, .notAuthorized):
            return true
        default:
            return false
        }
    }
}
