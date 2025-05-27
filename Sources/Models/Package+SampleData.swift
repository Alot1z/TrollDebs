import Foundation

extension Package {
    static var samplePackages: [Package] {
        [
            Package(
                identifier: "com.example.tweak1",
                name: "Tweak 1",
                version: "1.0.0",
                description: "A sample tweak for testing injection",
                author: "Tweak Author",
                section: "Tweaks",
                architecture: "iphoneos-arm64",
                maintainer: "Tweak Maintainer",
                depends: [],
                conflicts: [],
                provides: [],
                installedSize: 1024,
                filename: "tweak1.deb",
                size: 2048
            ),
            Package(
                identifier: "com.example.theme1",
                name: "Theme 1",
                version: "1.2.0",
                description: "A sample theme package",
                author: "Theme Author",
                section: "Themes",
                architecture: "iphoneos-arm64",
                maintainer: "Theme Maintainer",
                depends: ["com.example.tweak1"],
                conflicts: [],
                provides: [],
                installedSize: 5120,
                filename: "theme1.deb",
                size: 10240
            )
        ]
    }
    
    static var sampleInjectedPackage: Package {
        var package = Package(
            identifier: "com.example.injected",
            name: "Injected Tweak",
            version: "2.0.0",
            description: "A sample injected tweak",
            author: "Injection Expert",
            section: "Tweaks",
            architecture: "iphoneos-arm64",
            maintainer: "Tweak Maintainer",
            depends: [],
            conflicts: [],
            provides: [],
            installedSize: 2048,
            filename: "injected.deb",
            size: 4096
        )
        
        // Mark as injected for preview purposes
        InjectionDatabase.shared.addInjection(
            packageId: package.identifier,
            appBundleId: "com.apple.MobileSMS",
            files: ["/Library/MobileSubstrate/DynamicLibraries/InjectedTweak.dylib"]
        )
        
        return package
    }
}
