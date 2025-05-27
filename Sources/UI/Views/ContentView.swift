import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            PackageListView()
                .tabItem {
                    Image(systemName: "shippingbox")
                    Text("Packages")
                }
                .tag(0)
            
            InstalledAppsView()
                .tabItem {
                    Image(systemName: "app.badge")
                    Text("Installed")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(2)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
