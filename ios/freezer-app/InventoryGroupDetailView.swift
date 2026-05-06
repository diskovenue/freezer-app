//
//  InventoryGroupDetailView.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import SwiftUI

struct InventoryGroupDetailView: View {
    let ean: String
    let title: String
    let onConsumeClose: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: GroupDetailViewModel
    @State private var selectedUnit: SelectedUnit?
    @State private var hiddenUnitIDs: Set<UUID> = []
    @State private var removingUnitIDs: Set<UUID> = []

    init(ean: String, title: String, onConsumeClose: (() -> Void)? = nil) {
        self.ean = ean
        self.title = title
        self.onConsumeClose = onConsumeClose
        _vm = StateObject(wrappedValue: GroupDetailViewModel(ean: ean, title: title))
    }

    var body: some View {
        NavigationStack {
            List {
                if let msg = vm.errorMessage {
                    Section { Text(msg).foregroundStyle(.red) }
                }

                ForEach(renderedItems) { item in
                    Button {
                        selectedUnit = SelectedUnit(id: item.id, title: item.display_name)
                    } label: {
                        InventoryRow(item: item)
                    }
                    .opacity(hiddenUnitIDs.contains(item.id) ? 0 : 1)
                    .listRowBackground(hiddenUnitIDs.contains(item.id) ? AnyView(Color.clear) : AnyView(Color(uiColor: .secondarySystemGroupedBackground)))
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            let itemID = item.id
                            let itemTitle = item.display_name

                            AppHaptics.swipeAction()

                            hiddenUnitIDs.insert(itemID)
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 70_000_000)
                                _ = withAnimation(.snappy(duration: 0.18, extraBounce: 0)) {
                                    removingUnitIDs.insert(itemID)
                                }
                            }
                            Task {
                                try? await Task.sleep(nanoseconds: 300_000_000)
                                let didConsume = await vm.consume(id: itemID, title: itemTitle)
                                guard didConsume else { return }
                                await MainActor.run {
                                    if let onConsumeClose {
                                        onConsumeClose()
                                    } else {
                                        dismiss()
                                    }
                                }
                            }
                        } label: {
                            Label("Entnehmen", systemImage: "checkmark")
                        }
                        .tint(.green)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .animation(.snappy(duration: 0.28, extraBounce: 0), value: vm.items.map(\.id))
            .animation(.snappy(duration: 0.18, extraBounce: 0), value: removingUnitIDs)
            .task { await vm.load() }
            .onReceive(NotificationCenter.default.publisher(for: .inventoryDataDidChange)) { _ in
                Task { await vm.load() }
            }
        }
        .sheet(item: $selectedUnit) { sel in
            UnitDetailView(
                unitId: sel.id,
                displayName: sel.title,
                onConsumeClose: {
                    selectedUnit = nil
                    if let onConsumeClose {
                        onConsumeClose()
                    } else {
                        dismiss()
                    }
                }
            )
        }
    }

    private struct SelectedUnit: Identifiable {
        let id: UUID
        let title: String?
    }

    private var renderedItems: [UnitDisplayRow] {
        vm.items.filter { !removingUnitIDs.contains($0.id) }
    }
}
