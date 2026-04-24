//
//  CountBadge.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import SwiftUI

struct CountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.footnote.weight(.bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color(.secondarySystemBackground)))
    }
}
