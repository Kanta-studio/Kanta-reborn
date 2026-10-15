import SwiftUI

enum GeloVisualStyle {
    static let accent = Color.pink
    static let cardCornerRadius: CGFloat = 24

    static var pageBackground: Color {
        Color(uiColor: .systemGroupedBackground)
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
            .regularMaterial,
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
            .stroke(.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

struct GeloStatusPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                .thinMaterial,
                in: Capsule()
            )
    }
}

