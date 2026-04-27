//
//  CategoryChip.swift
//  freezer-app
//
//  Created by Andreas Gößl on 27.04.26.
//

import SwiftUI

struct CategoryChip: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .lineLimit(1)

                Text("\(count)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(badgeBackgroundColor))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(chipBackgroundColor)
            )
            .overlay(
                Capsule().strokeBorder(chipBorderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var chipBackgroundColor: Color {
        if isSelected {
            return colorScheme == .light ? Color.accentColor.opacity(0.18) : Color.accentColor.opacity(0.25)
        }
        return colorScheme == .light ? Color(.systemBackground) : Color(.secondarySystemBackground)
    }

    private var badgeBackgroundColor: Color {
        if isSelected {
            return colorScheme == .light ? Color.white.opacity(0.72) : Color.white.opacity(0.18)
        }
        return colorScheme == .light ? Color(.tertiarySystemBackground) : Color(.secondarySystemBackground)
    }

    private var chipBorderColor: Color {
        if isSelected {
            return colorScheme == .light ? Color.accentColor.opacity(0.28) : Color.white.opacity(0.12)
        }
        return colorScheme == .light ? Color(.separator).opacity(0.18) : Color.white.opacity(0.06)
    }
}
