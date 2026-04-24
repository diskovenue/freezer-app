//
//  InventoryGroupDetailView.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import SwiftUI

struct InventoryGroupDetailView: View {
    let group: InventoryGroup
    @ObservedObject var vm: InventoryViewModel

    var body: some View {
        List {
            ForEach(group.items) { item in
                InventoryRow(item: item)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            Task { await vm.consume(id: item.id) }
                        } label: {
                            Label("Entnehmen", systemImage: "checkmark")
                        }
                        .tint(.green)
                    }
            }
        }
        .navigationTitle(group.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
