import SwiftUI

struct InstalledAppsView: View {
    @State private var installedApps: [InstalledApp] = []
    @State private var showingFileImporter = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(installedApps, id: \.bundleIdentifier) { app in
                    VStack(alignment: .leading) {
                        Text(app.name)
                            .font(.headline)
                        Text(app.bundleIdentifier)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text("Version: \(app.version)")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Installed Apps")
            .toolbar {
                Button(action: { showingFileImporter = true }) {
                    Image(systemName: "plus")
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        installApp(at: url)
                    }
                case .failure(let error):
                    print("Error selecting file: \(error.localizedDescription)")
                }
            }
        }
        .onAppear {
            refreshApps()
        }
    }
    
    private func installApp(at url: URL) {
        do {
            try TrollStoreIntegration.shared.installIPA(at: url.path)
            refreshApps()
        } catch {
            print("Failed to install app: \(error)")
        }
    }
    
    private func refreshApps() {
        installedApps = TrollStoreIntegration.shared.listInstalledApps()
    }
}

struct InstalledAppsView_Previews: PreviewProvider {
    static var previews: some View {
        InstalledAppsView()
    }
}
