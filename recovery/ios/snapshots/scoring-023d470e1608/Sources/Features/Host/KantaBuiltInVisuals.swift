import SwiftUI

enum KantaVisualKind: String, CaseIterable {
    case still
    case motion
}

enum KantaBuiltInVisualPreset: String, CaseIterable, Identifiable {
    // Ten static presets.
    case bayanDawn
    case pearlSky
    case mangoGlow
    case deepLagoon
    case orchidNight
    case bambooMist
    case emberSunset
    case moonlitBay
    case coralHaze
    case indigoHorizon

    // Ten animated presets.
    case neonPulse
    case auroraFlow
    case starlightDrift
    case haloWaves
    case prismBloom
    case electricTide
    case cosmicVeil
    case fireflyField
    case dreamClouds
    case rhythmRings

    var id: String { rawValue }

    static var stillPresets: [Self] {
        Array(allCases.prefix(10))
    }

    static var motionPresets: [Self] {
        Array(allCases.suffix(10))
    }

    var kind: KantaVisualKind {
        Self.stillPresets.contains(self) ? .still : .motion
    }

    var displayName: String {
        switch self {
        case .bayanDawn: "Bayan Dawn"
        case .pearlSky: "Pearl Sky"
        case .mangoGlow: "Mango Glow"
        case .deepLagoon: "Deep Lagoon"
        case .orchidNight: "Orchid Night"
        case .bambooMist: "Bamboo Mist"
        case .emberSunset: "Ember Sunset"
        case .moonlitBay: "Moonlit Bay"
        case .coralHaze: "Coral Haze"
        case .indigoHorizon: "Indigo Horizon"
        case .neonPulse: "Neon Pulse"
        case .auroraFlow: "Aurora Flow"
        case .starlightDrift: "Starlight Drift"
        case .haloWaves: "Halo Waves"
        case .prismBloom: "Prism Bloom"
        case .electricTide: "Electric Tide"
        case .cosmicVeil: "Cosmic Veil"
        case .fireflyField: "Firefly Field"
        case .dreamClouds: "Dream Clouds"
        case .rhythmRings: "Rhythm Rings"
        }
    }

    var categoryLabel: String {
        switch self {
        case .bayanDawn, .pearlSky, .mangoGlow, .deepLagoon,
             .bambooMist, .emberSunset, .moonlitBay, .coralHaze,
             .indigoHorizon:
            KantaTerminology.scenic
        case .orchidNight, .cosmicVeil, .dreamClouds:
            KantaTerminology.realm
        default:
            KantaTerminology.loop
        }
    }

    var palette: [Color] {
        switch self {
        case .bayanDawn:
            [.indigo, .orange, .yellow]
        case .pearlSky:
            [.cyan.opacity(0.9), .white, .blue.opacity(0.75)]
        case .mangoGlow:
            [.orange, .yellow, .pink.opacity(0.7)]
        case .deepLagoon:
            [.black, .blue, .teal]
        case .orchidNight:
            [.black, .purple, .pink.opacity(0.7)]
        case .bambooMist:
            [.green.opacity(0.55), .mint.opacity(0.8), .white]
        case .emberSunset:
            [.black, .red.opacity(0.8), .orange]
        case .moonlitBay:
            [.black, .indigo, .cyan.opacity(0.65)]
        case .coralHaze:
            [.pink.opacity(0.9), .orange.opacity(0.7), .purple]
        case .indigoHorizon:
            [.black, .indigo, .blue]
        case .neonPulse:
            [.black, .blue, .pink]
        case .auroraFlow:
            [.black, .green, .cyan, .purple]
        case .starlightDrift:
            [.black, .indigo, .white]
        case .haloWaves:
            [.black, .cyan, .blue]
        case .prismBloom:
            [.purple, .pink, .orange, .cyan]
        case .electricTide:
            [.black, .blue, .cyan, .white]
        case .cosmicVeil:
            [.black, .purple, .indigo, .pink]
        case .fireflyField:
            [.black, .green.opacity(0.65), .yellow]
        case .dreamClouds:
            [.indigo, .pink.opacity(0.65), .cyan.opacity(0.6)]
        case .rhythmRings:
            [.black, .pink, .blue, .cyan]
        }
    }
}

struct KantaBuiltInVisualView: View {
    let preset: KantaBuiltInVisualPreset

    var body: some View {
        if preset.kind == .motion {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) {
                timeline in
                rendered(
                    time: timeline.date.timeIntervalSinceReferenceDate
                )
            }
        } else {
            rendered(time: 0)
        }
    }

    @ViewBuilder
    private func rendered(time: TimeInterval) -> some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                LinearGradient(
                    colors: preset.palette,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Canvas { context, canvasSize in
                    drawAmbientShapes(
                        context: &context,
                        size: canvasSize,
                        time: time
                    )
                }

                LinearGradient(
                    colors: [
                        .black.opacity(0.08),
                        .clear,
                        .black.opacity(0.30)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .drawingGroup()
    }

    private func drawAmbientShapes(
        context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval
    ) {
        let animated = preset.kind == .motion
        let phase = animated ? time * 0.20 : 0

        for index in 0..<12 {
            let seed = Double(index + 1)
            let xFraction = CGFloat(
                (sin(seed * 1.7 + phase) + 1) * 0.5
            )
            let yFraction = CGFloat(
                (cos(seed * 1.13 + phase * 0.8) + 1) * 0.5
            )
            let diameter =
                min(size.width, size.height)
                * CGFloat(0.08 + seed.truncatingRemainder(dividingBy: 5) * 0.018)

            let rect = CGRect(
                x: size.width * xFraction - diameter / 2,
                y: size.height * yFraction - diameter / 2,
                width: diameter,
                height: diameter
            )

            let opacity = 0.05 + Double(index % 4) * 0.025
            context.fill(
                Path(ellipseIn: rect),
                with: .color(.white.opacity(opacity))
            )
        }

        let horizon = size.height * 0.72
        var wave = Path()
        wave.move(to: CGPoint(x: 0, y: horizon))

        let points = 80
        for index in 0...points {
            let fraction = CGFloat(index) / CGFloat(points)
            let x = size.width * fraction
            let oscillation =
                sin(Double(fraction) * .pi * 5 + phase * 2.2)
            let y = horizon + CGFloat(oscillation) * size.height * 0.018
            wave.addLine(to: CGPoint(x: x, y: y))
        }

        wave.addLine(to: CGPoint(x: size.width, y: size.height))
        wave.addLine(to: CGPoint(x: 0, y: size.height))
        wave.closeSubpath()

        context.fill(
            wave,
            with: .color(.black.opacity(0.18))
        )
    }
}

