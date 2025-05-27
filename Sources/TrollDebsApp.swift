import SwiftUI

@main
struct TrollDebsApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            // Package Browser Tab
            NavigationView {
                ContentView()
            }
            .tabItem {
                Label("Packages", systemImage: "shippingbox")
            }
            
            // Injected Packages Tab
            NavigationView {
                InjectedPackagesView()
            }
            .tabItem {
                Label("Injected", systemImage: "cube")
            }
            
            // Settings Tab
            NavigationView {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
        .accentColor(.blue) // Set the accent color for the entire app
    }
}

// Placeholder for Settings View
struct SettingsView: View {
    var body: some View {
        Form {
            Section(header: Text("General")) {
                Toggle("Auto-update packages", isOn: .constant(true))
                Toggle("Show beta packages", isOn: .constant(false))
            }
            
            Section(header: Text("About")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                Link(destination: URL(string: "https://github.com/yourusername/TrollDebs")!) {
                    Label("GitHub Repository", systemImage: "link")
                }
                
                Link(destination: URL(string: "mailto:support@example.com")!) {
                    Label("Contact Support", systemImage: "envelope")
                }
            }
        }
        .navigationTitle("Settings")
    }
}
