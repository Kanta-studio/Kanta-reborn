import SwiftUI

struct KantaBrandMark: View {
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: size * 0.22,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.10, blue: 0.36),
                        Color(red: 0.05, green: 0.35, blue: 0.95),
                        Color(red: 0.70, green: 0.08, blue: 0.86)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            Image(systemName: "sun.max.fill")
                .font(.system(size: size * 0.34))
                .foregroundStyle(.yellow.opacity(0.9))
                .offset(y: -size * 0.22)

            HStack(spacing: size * 0.28) {
                Image(systemName: "star.fill")
                Image(systemName: "star.fill")
                Image(systemName: "star.fill")
            }
            .font(.system(size: size * 0.075))
            .foregroundStyle(.yellow.opacity(0.88))
            .offset(y: -size * 0.08)

            VStack(spacing: size * 0.025) {
                Capsule()
                    .fill(.white.opacity(0.24))
                    .frame(
                        width: size * 0.40,
                        height: size * 0.085
                    )

                ZStack {
                    RoundedRectangle(
                        cornerRadius: size * 0.10,
                        style: .continuous
                    )
                    .fill(.black.opacity(0.72))
                    .frame(
                        width: size * 0.62,
                        height: size * 0.46
                    )

                    Circle()
                        .stroke(.white.opacity(0.20), lineWidth: 1)
                        .frame(
                            width: size * 0.28,
                            height: size * 0.28
                        )

                    Image(systemName: "mic.fill")
                        .font(.system(
                            size: size * 0.22,
                            weight: .semibold
                        ))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .white, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .offset(y: size * 0.13)
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(
                cornerRadius: size * 0.22,
                style: .continuous
            )
            .stroke(.white.opacity(0.14), lineWidth: 1)
        }
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

