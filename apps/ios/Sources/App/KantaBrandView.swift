import SwiftUI

/// Displays the exact AppIcon artwork as a normal image-set asset.
struct KantaBrandMark: View {
    var size: CGFloat = 64

    var body: some View {
        Image("KantaBrandArtwork")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: size * 0.22,
                    style: .continuous
                )
            )
            .accessibilityHidden(true)
    }
}

struct KantaBrandLockup: View {
    var compact = false

    var body: some View {
        HStack(spacing: 12) {
            KantaBrandMark(size: compact ? 44 : 58)

            VStack(alignment: .leading, spacing: 2) {
                Text("KANTA")
                    .foregroundStyle(GeloVisualStyle.gold)
                    .font(
                        compact
                        ? .headline.bold()
                        : .title2.bold()
                    )

                Text("Your music. Your stage.")
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "KANTA. Your music. Your stage."
        )
    }
}

