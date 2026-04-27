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

                // Title row: "3×" + Title
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if group.count > 1 {
                        CountPrefix(count: group.count)
                    }

                    Text(group.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }

                subline
            }

            Spacer(minLength: 8)

            if let days = group.minDaysLeft {
                DaysLeftBadge(daysLeft: days)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Subline (Ort + • + Einlagedatum)
    private var subline: some View {
        let locText = (group.locationName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        return HStack(spacing: 6) {
            if !locText.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "archivebox")
                    Text(locText)
                }
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
            }

            if let frozen = group.minFrozenAtFormatted {
                Text("•\(thinSpace)\(frozen)")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .font(.subheadline)
        .lineLimit(1)
        .truncationMode(.tail)
    }

    private var thinSpace: String { "\u{2009}" } // thin space
}

private struct CountPrefix: View {
    let count: Int

    var body: some View {
        Text("\(count)×")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
    }
}

private struct DaysLeftBadge: View {
    let daysLeft: Int

    var body: some View {
        Text(label)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
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

    private var borderColor: Color {
        // sorgt dafür, dass die Pill-Form in Dark Mode sichtbar bleibt
        Color.white.opacity(0.10)
    }
}
