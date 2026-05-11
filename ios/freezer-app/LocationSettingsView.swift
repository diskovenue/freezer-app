import SwiftUI

struct LocationSettingsView: View {
    @StateObject private var vm = LocationsViewModel()
    @State private var showCreateLocation = false

    var body: some View {
        List {
            if let msg = vm.errorMessage {
                Section { Text(msg).foregroundStyle(.red) }
            }

            Section {
                ForEach(vm.items) { location in
                    NavigationLink {
                        EditLocationView(location: location, vm: vm)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 28)

                            Text(location.name)
                                .font(.headline)

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onMove { source, destination in
                    vm.moveLocations(from: source, to: destination)
                }
            } footer: {
                Text("Orte können per Drag & Drop sortiert werden.")
                    .padding(.top, 8)
            }
        }
        .navigationTitle("Orte")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateLocation = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Ort hinzufügen")
            }
        }
        .sheet(isPresented: $showCreateLocation) {
            NavigationStack {
                EditLocationView(location: nil, vm: vm)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 20)
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}
