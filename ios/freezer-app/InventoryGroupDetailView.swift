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

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: GroupDetailViewModel
    @State private var selectedUnit: SelectedUnit?

    init(ean: String, title: String) {
        self.ean = ean
        self.title = title
        _vm = StateObject(wrappedValue: GroupDetailViewModel(ean: ean, title: title))
    }

    var body: some View {
        NavigationStack {
            List {
                if let msg = vm.errorMessage {
                    Section { Text(msg).foregroundStyle(.red) }
                }

                ForEach(vm.items) { item in
                    Button {
                        selectedUnit = SelectedUnit(id: item.id, title: item.display_name)
                    } label: {
                        InventoryRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            Task { await vm.consume(id: item.id, title: item.display_name) }
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
            .task { await vm.load() }
            .overlay(alignment: .bottom) {
                if let undo = vm.undoItem {
                    UndoBanner(
                        title: "\(undo.title) entnommen",
                        duration: 5,
                        onUndo: { Task { await vm.undoLastConsume() } },
                        onDismiss: { vm.undoItem = nil }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.2), value: vm.undoItem?.id)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .inventoryDataDidChange)) { _ in
                Task { await vm.load() }
            }
        }
        .sheet(item: $selectedUnit) { sel in
            UnitDetailView(unitId: sel.id, displayName: sel.title)
        }
    }

    private struct SelectedUnit: Identifiable {
        let id: UUID
        let title: String?
    }
}
