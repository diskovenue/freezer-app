//
//  Untitled.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import SwiftUI

struct InventoryGroupRow: View {
    let group: InventoryGroup

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(group.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let loc = group.locationName, !loc.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "archivebox")
                            Text(loc)
                        }
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                    }

                    if let due = group.minDueDateFormatted {
                        Text("• \(due)")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                if let days = group.minDaysLeft {
                    DaysLeftBadge(daysLeft: days)
                }

                if group.count > 1 {
                    CountBadge(count: group.count)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Farbiger Badge wie vorher (kritisch/soon/neutral)
private struct DaysLeftBadge: View {
    let daysLeft: Int

    var body: some View {
        Text(label)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(backgroundColor))
            .foregroundStyle(foregroundColor)
    }

    private var label: String {
        if daysLeft < 0 { return "drüber \(abs(daysLeft))T" }
        if daysLeft == 0 { return "heute" }
        if daysLeft == 1 { return "1 Tag" }
        return "\(daysLeft) Tage"
    }

    private var backgroundColor: Color {
        if daysLeft <= 2 { return Color.red.opacity(0.18) }
        if daysLeft <= 7 { return Color.orange.opacity(0.18) }
        return Color(.secondarySystemBackground)
    }

    private var foregroundColor: Color {
        if daysLeft <= 2 { return .red }
        if daysLeft <= 7 { return .orange }
        return .secondary
    }
}
