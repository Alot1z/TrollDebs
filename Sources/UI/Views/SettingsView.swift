import SwiftUI

struct SettingsView: View {
    @AppStorage("enableAdvancedFeatures") private var enableAdvancedFeatures = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("General")) {
                    Toggle("Advanced Features", isOn: $enableAdvancedFeatures)
                    
                    Button(action: refreshAppRegistrations) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh App Registrations")
                        }
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(.gray)
                    }
                }
                
                Section {
                    Button(action: showAcknowledgements) {
                        Text("Acknowledgements")
                    }
                    
                    Link("GitHub Repository", destination: URL(string: "https://github.com/yourusername/TrollDebs")!)
                }
            }
            .navigationTitle("Settings")
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Success"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func refreshAppRegistrations() {
        TrollStoreIntegration.shared.refreshAppRegistrations()
        alertMessage = "App registrations refreshed successfully"
        showingAlert = true
    }
    
    private func showAcknowledgements() {
        // Show acknowledgements
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
