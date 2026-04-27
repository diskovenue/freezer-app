//
//  UndoBanner.swift
//  freezer-app
//
//  Created by Andreas Gößl on 27.04.26.
//

import SwiftUI
import Combine

struct UndoBanner: View {
    let title: String
    let duration: TimeInterval
    let onUndo: () -> Void
    let onDismiss: () -> Void

    @State private var startDate = Date()
    @State private var now = Date()
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Button("Rückgängig") { onUndo() }
                    .font(.subheadline.weight(.semibold))

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.secondary)
            }

            progressBar
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .onAppear {
            startDate = Date()
            now = startDate
        }
        .onReceive(timer) { value in
            now = value
        }
    }

    private var progress: CGFloat {
        let elapsed = now.timeIntervalSince(startDate)
        let p = 1.0 - (elapsed / duration)
        return max(0, min(1, p))
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.10))

                Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(0.65))
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: 3)
        .accessibilityLabel("Undo Countdown")
    }
}
