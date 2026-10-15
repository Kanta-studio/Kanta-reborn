import SwiftUI

/// Native palette mirrors the published PublicSite/style.css.
enum GeloVisualStyle {
    static let accent = Color(red: 184.0 / 255, green: 102.0 / 255, blue: 215.0 / 255)
    static let accentEnd = Color(red: 67.0 / 255, green: 107.0 / 255, blue: 202.0 / 255)
    static let cyan = Color(red: 133.0 / 255, green: 231.0 / 255, blue: 237.0 / 255)
    static let gold = Color(red: 246.0 / 255, green: 199.0 / 255, blue: 113.0 / 255)
    static let pageBackground = Color(red: 14.0 / 255, green: 16.0 / 255, blue: 32.0 / 255)
    static let cardTop = Color(red: 37.0 / 255, green: 35.0 / 255, blue: 60.0 / 255)
    static let cardBottom = Color(red: 19.0 / 255, green: 26.0 / 255, blue: 48.0 / 255)
    static let cardBorder = Color(red: 141.0 / 255, green: 124.0 / 255, blue: 164.0 / 255)
    static let cardCornerRadius: CGFloat = 24

    static let pageGradient = LinearGradient(
        colors: [
            Color(red: 40.0 / 255, green: 27.0 / 255, blue: 66.0 / 255),
            pageBackground,
            Color(red: 18.0 / 255, green: 30.0 / 255, blue: 55.0 / 255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let actionGradient = LinearGradient(
        colors: [accent, accentEnd],
        startPoint: .leading,
        endPoint: .trailing
    )
}

extension View {
    /// Normalize List/Form surfaces without overriding UIKit file-picker chrome.
    func kantaListSurface() -> some View {
        scrollContentBackground(.hidden)
            .background(GeloVisualStyle.pageBackground)
    }
}

struct GeloSectionCard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: () -> Content

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [GeloVisualStyle.cardTop, GeloVisualStyle.cardBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(
                cornerRadius: GeloVisualStyle.cardCornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: GeloVisualStyle.cardCornerRadius,
                style: .continuous
            )
            .stroke(GeloVisualStyle.cardBorder.opacity(0.35), lineWidth: 1)
        }
    }
}

struct GeloStatusPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(GeloVisualStyle.cyan)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                GeloVisualStyle.accent.opacity(0.14),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(GeloVisualStyle.cardBorder.opacity(0.35), lineWidth: 1)
            }
    }
}

