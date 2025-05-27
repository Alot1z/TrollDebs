import SwiftUI

struct PackageListView: View {
    @StateObject private var viewModel = PackageListViewModel()
    @State private var showingFileImporter = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading && viewModel.packages.isEmpty {
                    ProgressView("Loading packages...")
                        .scaleEffect(1.5)
                } else if viewModel.filteredPackages.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        if viewModel.searchText.isEmpty {
                            VStack(spacing: 8) {
                                Text("No Packages")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text("Install your first package by tapping the + button")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        } else {
                            Text("No packages found for \"\(viewModel.searchText)\"")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    List {
                        ForEach(viewModel.filteredPackages) { package in
                            NavigationLink(destination: PackageDetailView(package: package)) {
                                PackageRow(package: package)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.removePackage(package)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Packages")
            .searchable(text: $viewModel.searchText, prompt: "Search packages")
            .refreshable {
                viewModel.refresh()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingFileImporter = true }) {
                        Image(systemName: "plus")
                    }
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
                        viewModel.installPackage(at: url)
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                }
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage())
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Previews

struct PackageListView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PackageListView()
                .previewDisplayName("Empty State")
            
            let viewModel = PackageListViewModel()
            let _ = viewModel.packages = Package.samplePackages
            let _ = viewModel.filteredPackages = Package.samplePackages
            
            NavigationView {
                List {
                    ForEach(viewModel.filteredPackages) { package in
                        PackageRow(package: package)
                    }
                }
                .navigationTitle("Packages")
            }
            .previewDisplayName("With Packages")
        }
    }
}
