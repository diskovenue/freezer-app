//
//  InventoryRow.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import SwiftUI

struct InventoryRow: View {
    let item: UnitDisplayRow

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.display_name ?? "Unbenannt")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let loc = item.location_name, !loc.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "archivebox")
                            Text(loc)
                        }
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)   // Location bekommt Platz
                    }

                    if let due = item.due_date, !due.isEmpty {
                        Text("• \(formatDate(due))")
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

            if let days = item.days_left {
                badge(daysLeft: days, attention: item.attention_reason)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func badge(daysLeft: Int, attention: String?) -> some View {
        let text = daysLeftText(daysLeft)
        let isCritical = (attention == "mhd_2") || daysLeft <= 2
        let isSoon = (attention == "mhd_7") || (daysLeft <= 7)

        Text(text)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(
                    isCritical ? Color.red.opacity(0.18) :
                    isSoon ? Color.orange.opacity(0.18) :
                    Color(.secondarySystemBackground)
                )
            )
            .foregroundStyle(isCritical ? .red : (isSoon ? .orange : .secondary))
    }

    private func daysLeftText(_ days: Int) -> String {
        if days < 0 { return "+ \(abs(days)) Tage" }
        if days == 0 { return "heute" }
        if days == 1 { return "1 Tag" }
        return "\(days) Tage"
    }
    
    private func formatDate(_ isoDate: String) -> String {
        // isoDate: "YYYY-MM-DD"
        let inFmt = DateFormatter()
        inFmt.locale = Locale(identifier: "en_US_POSIX")
        inFmt.dateFormat = "yyyy-MM-dd"

        let outFmt = DateFormatter()
        outFmt.locale = Locale(identifier: "de_DE")
        outFmt.dateFormat = "dd.MM.yy"

        guard let d = inFmt.date(from: isoDate) else { return isoDate }
        return outFmt.string(from: d)
    }
}
